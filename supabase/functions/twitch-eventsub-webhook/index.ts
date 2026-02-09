/**
 * Twitch EventSub Webhook Handler
 * 
 * Handles Twitch EventSub notifications for:
 * - channel.subscribe (new subscriptions)
 * - channel.subscription.end (subscription expired/cancelled)
 * - channel.subscription.gift (gifted subscriptions)
 * 
 * Automatically grants/revokes premium access based on subscription status
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { createHmac } from 'https://deno.land/std@0.177.0/node/crypto.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, twitch-eventsub-message-id, twitch-eventsub-message-signature, twitch-eventsub-message-timestamp, twitch-eventsub-message-type, twitch-eventsub-subscription-type',
};

interface EventSubNotification {
  subscription: {
    type: string;
    version: string;
  };
  event: {
    user_id: string;
    user_login: string;
    user_name: string;
    broadcaster_user_id: string;
    broadcaster_user_login: string;
    broadcaster_user_name: string;
    tier: string;
    is_gift?: boolean;
  };
}

interface EventSubChallenge {
  challenge: string;
  subscription: {
    type: string;
  };
}

/**
 * Verify Twitch EventSub signature
 */
function verifySignature(
  messageId: string,
  timestamp: string,
  body: string,
  signature: string
): boolean {
  const secret = Deno.env.get('TWITCH_EVENTSUB_SECRET');
  if (!secret) {
    console.error('TWITCH_EVENTSUB_SECRET not configured');
    return false;
  }

  const message = messageId + timestamp + body;
  const expectedSignature = 'sha256=' + createHmac('sha256', secret)
    .update(message)
    .digest('hex');

  return signature === expectedSignature;
}

/**
 * Grant premium access to user
 * If user already has active Twitch premium, add 33 days to their existing time
 */
async function grantPremium(supabase: any, userId: string) {
  // Check if user already has premium from any source
  const { data: existingPremium } = await supabase
    .from('user_premium_status')
    .select('premium_source, premium_expires_at, is_premium')
    .eq('user_id', userId)
    .single();

  // NEVER overwrite Apple/Google IAP or Stripe - they have higher priority
  // Hierarchy: Apple/Google > Stripe > Twitch
  if (existingPremium?.is_premium && 
      (existingPremium.premium_source === 'apple' || 
       existingPremium.premium_source === 'google' ||
       existingPremium.premium_source === 'stripe')) {
    console.log(`User has ${existingPremium.premium_source} premium (higher priority) - not overwriting with Twitch`);
    
    // Create notification (generic message - don't mention Twitch)
    const { error: notifError } = await supabase.from('notifications').insert({
      user_id: userId,
      type: 'subscription_conflict',
      title: 'Active Subscription Detected',
      message: 'You already have an active premium subscription. Please cancel your existing subscription or wait until it expires.',
      created_at: new Date().toISOString(),
    });
    if (notifError) {
      console.error('Failed to create subscription conflict notification:', notifError);
    }
    
    return;
  }

  let expiresAt: Date;

  if (existingPremium?.premium_source === 'twitch' && existingPremium.is_premium) {
    // User already has Twitch premium - add 33 days to their current expiry
    const currentExpiry = new Date(existingPremium.premium_expires_at);
    const now = new Date();
    
    // If their current expiry is in the future, add to that date
    // Otherwise, add to now (in case they're in grace period)
    const baseDate = currentExpiry > now ? currentExpiry : now;
    expiresAt = new Date(baseDate);
    expiresAt.setDate(expiresAt.getDate() + 33);
    
    console.log(`User has existing Twitch premium until ${currentExpiry.toISOString()}, extending to ${expiresAt.toISOString()}`);
  } else {
    // New Twitch premium - 30 days membership + 3 days grace period = 33 days
    expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 33);
    console.log(`Granting new Twitch premium until ${expiresAt.toISOString()}`);
  }

  const { error } = await supabase
    .from('user_premium_status')
    .upsert({
      user_id: userId,
      is_premium: true,
      premium_source: 'twitch',
      premium_expires_at: expiresAt.toISOString(),
      updated_at: new Date().toISOString(),
    }, {
      onConflict: 'user_id',
    });

  if (error) {
    console.error('Failed to grant premium:', error);
    throw error;
  }

  console.log(`✅ Premium granted to user ${userId}`);
}

/**
 * Revoke premium access from user (only if source was Twitch and grace period expired)
 */
async function revokePremium(supabase: any, userId: string) {
  // First check if their premium is from Twitch and when it expires
  const { data: premiumStatus } = await supabase
    .from('user_premium_status')
    .select('premium_source, premium_expires_at')
    .eq('user_id', userId)
    .single();

  // Only revoke if premium was granted via Twitch
  if (premiumStatus?.premium_source === 'twitch') {
    // Check if grace period has expired (premium_expires_at is in the past)
    const expiryDate = new Date(premiumStatus.premium_expires_at);
    const now = new Date();
    
    if (expiryDate > now) {
      console.log(`ℹ️  User ${userId} still in grace period until ${expiryDate.toISOString()}, not revoking yet`);
      return;
    }
    
    console.log(`Grace period expired for user ${userId}, revoking premium`);
    const { error } = await supabase
      .from('user_premium_status')
      .update({
        is_premium: false,
        premium_source: null,
        premium_expires_at: new Date().toISOString(), // Set to now
        updated_at: new Date().toISOString(),
      })
      .eq('user_id', userId);

    if (error) {
      console.error('Failed to revoke premium:', error);
      throw error;
    }

    console.log(`❌ Premium revoked from user ${userId}`);
  } else {
    console.log(`ℹ️  User ${userId} has premium from ${premiumStatus?.premium_source || 'unknown source'}, not revoking`);
  }
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get Twitch headers
    const messageId = req.headers.get('twitch-eventsub-message-id');
    const timestamp = req.headers.get('twitch-eventsub-message-timestamp');
    const signature = req.headers.get('twitch-eventsub-message-signature');
    const messageType = req.headers.get('twitch-eventsub-message-type');

    if (!messageId || !timestamp || !signature) {
      console.error('Missing required Twitch headers');
      return new Response('Missing headers', { status: 400 });
    }

    // Get request body
    const body = await req.text();

    // Verify signature
    if (!verifySignature(messageId, timestamp, body, signature)) {
      console.error('Invalid signature');
      return new Response('Invalid signature', { status: 403 });
    }

    const payload = JSON.parse(body);

    // Handle webhook verification challenge
    if (messageType === 'webhook_callback_verification') {
      const challenge = (payload as EventSubChallenge).challenge;
      console.log('Webhook verification challenge received');
      return new Response(challenge, {
        headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
      });
    }

    // Handle notification
    if (messageType === 'notification') {
      const notification = payload as EventSubNotification;
      const eventType = notification.subscription.type;
      const event = notification.event;

      console.log(`📬 Received ${eventType} for user ${event.user_name} (${event.user_id})`);

      // Create Supabase admin client
      const supabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      );

      // Find StatusXP user with this Twitch ID
      const { data: profile } = await supabase
        .from('profiles')
        .select('id')
        .eq('twitch_user_id', event.user_id)
        .single();

      if (!profile) {
        console.log(`ℹ️  No StatusXP user found with Twitch ID ${event.user_id}`);
        return new Response('ok', { headers: corsHeaders });
      }

      // Handle different event types
      switch (eventType) {
        case 'channel.subscribe':
        case 'channel.subscription.gift':
          console.log(`🎁 New subscription: ${event.user_name} (Tier ${event.tier})`);
          await grantPremium(supabase, profile.id);
          break;

        case 'channel.subscription.message':
          console.log(`🔄 Subscription renewal: ${event.user_name} (Tier ${event.tier})`);
          await grantPremium(supabase, profile.id); // Reset to 33 days
          break;

        case 'channel.subscription.end':
          console.log(`🔚 Subscription ended: ${event.user_name}`);
          await revokePremium(supabase, profile.id);
          break;

        default:
          console.log(`ℹ️  Unhandled event type: ${eventType}`);
      }

      return new Response('ok', { headers: corsHeaders });
    }

    // Handle revocation
    if (messageType === 'revocation') {
      console.log('📮 Subscription revoked by Twitch');
      return new Response('ok', { headers: corsHeaders });
    }

    console.log(`⚠️  Unknown message type: ${messageType}`);
    return new Response('ok', { headers: corsHeaders });

  } catch (error) {
    console.error('Error processing EventSub webhook:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to process webhook',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
