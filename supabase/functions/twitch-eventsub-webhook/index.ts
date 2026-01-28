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
 */
async function grantPremium(supabase: any, userId: string) {
  // Calculate expiry (1 month from now)
  const expiresAt = new Date();
  expiresAt.setMonth(expiresAt.getMonth() + 1);

  const { error } = await supabase
    .from('user_premium_status')
    .upsert({
      user_id: userId,
      is_premium: true,
      premium_source: 'twitch',
      expires_at: expiresAt.toISOString(),
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
 * Revoke premium access from user (only if source was Twitch)
 */
async function revokePremium(supabase: any, userId: string) {
  // First check if their premium is from Twitch
  const { data: premiumStatus } = await supabase
    .from('user_premium_status')
    .select('premium_source')
    .eq('user_id', userId)
    .single();

  // Only revoke if premium was granted via Twitch
  if (premiumStatus?.premium_source === 'twitch') {
    const { error } = await supabase
      .from('user_premium_status')
      .update({
        is_premium: false,
        expires_at: new Date().toISOString(), // Set to now
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
