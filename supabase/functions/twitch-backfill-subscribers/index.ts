/**
 * Manually Check ALL Twitch Subscribers
 * 
 * This function checks subscription status for ALL users with linked Twitch accounts
 * and updates their premium status accordingly.
 * 
 * Use this to backfill premium status for users who subscribed before
 * EventSub webhooks were set up.
 * 
 * Call via:
 * curl -X POST 'https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-backfill-subscribers' \
 *   -H 'Authorization: Bearer SERVICE_ROLE_KEY'
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface TwitchAppAccessTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}

interface TwitchSubscriptionCheckResponse {
  data: Array<{
    broadcaster_id: string;
    tier: string;
  }>;
}

async function getAppAccessToken(): Promise<string> {
  const clientId = Deno.env.get('TWITCH_CLIENT_ID');
  const clientSecret = Deno.env.get('TWITCH_CLIENT_SECRET');

  if (!clientId || !clientSecret) {
    throw new Error('Twitch credentials not configured');
  }

  const response = await fetch('https://id.twitch.tv/oauth2/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: 'client_credentials',
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    console.error('Failed to get app access token:', error);
    throw new Error('Failed to authenticate with Twitch');
  }

  const data: TwitchAppAccessTokenResponse = await response.json();
  return data.access_token;
}

async function checkSubscription(appToken: string, userId: string): Promise<{ isSubscribed: boolean; tier?: string }> {
  const clientId = Deno.env.get('TWITCH_CLIENT_ID');
  const broadcasterId = Deno.env.get('TWITCH_BROADCASTER_ID');

  if (!broadcasterId) {
    throw new Error('TWITCH_BROADCASTER_ID not configured');
  }

  try {
    const response = await fetch(
      `https://api.twitch.tv/helix/subscriptions/user?broadcaster_id=${broadcasterId}&user_id=${userId}`,
      {
        headers: {
          'Authorization': `Bearer ${appToken}`,
          'Client-Id': clientId!,
        },
      }
    );

    if (response.status === 404) {
      return { isSubscribed: false };
    }

    if (!response.ok) {
      const error = await response.text();
      console.error(`Failed to check subscription for ${userId}:`, error);
      return { isSubscribed: false };
    }

    const data: TwitchSubscriptionCheckResponse = await response.json();
    
    if (data.data && data.data.length > 0) {
      return {
        isSubscribed: true,
        tier: data.data[0].tier,
      };
    }

    return { isSubscribed: false };
  } catch (error) {
    console.error(`Error checking subscription for ${userId}:`, error);
    return { isSubscribed: false };
  }
}

async function updatePremiumStatus(supabase: any, userId: string, isSubscribed: boolean) {
  if (isSubscribed) {
    // Check if user already has premium from any source
    const { data: existingPremium } = await supabase
      .from('user_premium_status')
      .select('premium_source, premium_expires_at, is_premium, premium_since')
      .eq('user_id', userId)
      .single();

    // NEVER overwrite Apple/Google IAP or Stripe - they have higher priority
    // Hierarchy: Apple/Google > Stripe > Twitch
    if (existingPremium?.is_premium && 
        (existingPremium.premium_source === 'apple' || 
         existingPremium.premium_source === 'google' ||
         existingPremium.premium_source === 'stripe')) {
      console.log(`User ${userId} has ${existingPremium.premium_source} premium (higher priority) - not overwriting with Twitch`);
      return 'skipped_higher_priority';
    }

    let expiresAt: Date;

    if (existingPremium?.premium_source === 'twitch' && existingPremium.is_premium) {
      // User already has Twitch premium - add 33 days to their current expiry
      const currentExpiry = new Date(existingPremium.premium_expires_at);
      const now = new Date();
      
      const baseDate = currentExpiry > now ? currentExpiry : now;
      expiresAt = new Date(baseDate);
      expiresAt.setDate(expiresAt.getDate() + 33);
      console.log(`Extending Twitch premium for ${userId} to ${expiresAt.toISOString()}`);
    } else {
      // New Twitch premium - 30 days + 3 days grace period
      expiresAt = new Date();
      expiresAt.setDate(expiresAt.getDate() + 33);
      console.log(`Granting new Twitch premium for ${userId} until ${expiresAt.toISOString()}`);
    }

    const { error } = await supabase
      .from('user_premium_status')
      .upsert({
        user_id: userId,
        is_premium: true,
        premium_source: 'twitch',
        premium_expires_at: expiresAt.toISOString(),
        premium_since: existingPremium?.premium_since || new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id',
      });

    if (error) {
      console.error(`Failed to grant premium to ${userId}:`, error);
      return 'error';
    }

    return 'granted';
  } else {
    // Check current premium source before revoking
    const { data: premiumStatus } = await supabase
      .from('user_premium_status')
      .select('premium_source, premium_expires_at, is_premium')
      .eq('user_id', userId)
      .single();

    // Only revoke if premium was from Twitch and grace period expired
    if (premiumStatus?.premium_source === 'twitch' && premiumStatus.is_premium) {
      const expiryDate = new Date(premiumStatus.premium_expires_at);
      const now = new Date();
      
      if (expiryDate > now) {
        console.log(`User ${userId} still in grace period - not revoking yet`);
        return 'grace_period';
      }

      console.log(`Grace period expired for ${userId}, revoking Twitch premium`);
      const { error } = await supabase
        .from('user_premium_status')
        .update({
          is_premium: false,
          premium_source: null,
          premium_expires_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', userId);

      if (error) {
        console.error(`Failed to revoke premium from ${userId}:`, error);
        return 'error';
      }

      return 'revoked';
    } else if (premiumStatus?.premium_source && premiumStatus.premium_source !== 'twitch') {
      console.log(`User ${userId} has premium from ${premiumStatus.premium_source}, not revoking`);
    }

    return 'no_action';
  }
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    console.log('🔄 Starting Twitch subscriber backfill...');

    // Create Supabase admin client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Get all users with linked Twitch accounts
    const { data: profiles, error: profilesError } = await supabase
      .from('profiles')
      .select('id, twitch_user_id')
      .not('twitch_user_id', 'is', null);

    if (profilesError) {
      console.error('Error fetching profiles:', profilesError);
      throw profilesError;
    }

    if (!profiles || profiles.length === 0) {
      console.log('ℹ️  No users with linked Twitch accounts found');
      return new Response(
        JSON.stringify({
          message: 'No users with linked Twitch accounts',
          checked: 0,
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log(`Found ${profiles.length} users with linked Twitch accounts`);

    // Get Twitch app access token
    const appToken = await getAppAccessToken();
    
    // Get broadcaster ID to exclude them from checks
    const broadcasterId = Deno.env.get('TWITCH_BROADCASTER_ID');

    // Process each user
    const results = {
      total: profiles.length,
      granted: 0,
      revoked: 0,
      grace_period: 0,
      skipped_higher_priority: 0,
      skipped_broadcaster: 0,
      no_action: 0,
      errors: 0,
    };

    for (const profile of profiles) {
      try {
        console.log(`Checking ${profile.twitch_user_id}...`);
        
        // Skip the broadcaster themselves (they shouldn't get auto-premium)
        if (profile.twitch_user_id === broadcasterId) {
          console.log(`  ⏩ Skipping broadcaster`);
          results.skipped_broadcaster++;
          continue;
        }
        
        const { isSubscribed, tier } = await checkSubscription(appToken, profile.twitch_user_id);
        
        console.log(`  ${isSubscribed ? `✅ Subscribed (${tier})` : '❌ Not subscribed'}`);
        
        const result = await updatePremiumStatus(supabase, profile.id, isSubscribed);
        
        if (result === 'granted') {
          results.granted++;
          console.log(`  ✅ Premium granted`);
        } else if (result === 'revoked') {
          results.revoked++;
          console.log(`  ❌ Premium revoked`);
        } else if (result === 'grace_period') {
          results.grace_period++;
        } else if (result === 'skipped_higher_priority') {
          results.skipped_higher_priority++;
        } else if (result === 'no_action') {
          results.no_action++;
        } else if (result === 'error') {
          results.errors++;
        }
      } catch (error) {
        console.error(`Error processing ${profile.twitch_user_id}:`, error);
        results.errors++;
      }
    }

    console.log('✅ Backfill complete');
    console.log(results);

    return new Response(
      JSON.stringify({
        message: 'Twitch subscriber backfill complete',
        results,
        completed_at: new Date().toISOString(),
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );

  } catch (error) {
    console.error('Error in backfill:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to backfill subscribers',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
