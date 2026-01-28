/**
 * Check Twitch Subscription Status Edge Function
 * 
 * Checks if a user with a linked Twitch account is currently subscribed
 * Can be called manually to refresh subscription status
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

/**
 * Get Twitch app access token (for API calls)
 */
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

/**
 * Check if user is subscribed to broadcaster
 */
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
      console.error('Failed to check subscription:', error);
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
    console.error('Error checking subscription:', error);
    return { isSubscribed: false };
  }
}

/**
 * Update premium status based on subscription
 */
async function updatePremiumStatus(supabase: any, userId: string, isSubscribed: boolean) {
  if (isSubscribed) {
    // Grant premium
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

    if (error) throw error;
  } else {
    // Check current premium source before revoking
    const { data: premiumStatus } = await supabase
      .from('user_premium_status')
      .select('premium_source')
      .eq('user_id', userId)
      .single();

    // Only revoke if premium was from Twitch
    if (premiumStatus?.premium_source === 'twitch') {
      const { error } = await supabase
        .from('user_premium_status')
        .update({
          is_premium: false,
          expires_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', userId);

      if (error) throw error;
    }
  }
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get user from authorization header
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser();

    if (userError || !user) {
      throw new Error('Unauthorized');
    }

    // Get user's Twitch ID
    const { data: profile } = await supabaseClient
      .from('profiles')
      .select('twitch_user_id')
      .eq('id', user.id)
      .single();

    if (!profile?.twitch_user_id) {
      return new Response(
        JSON.stringify({
          error: 'No Twitch account linked',
          isLinked: false,
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 404,
        }
      );
    }

    console.log(`Checking subscription for Twitch user ${profile.twitch_user_id}`);

    // Get app access token
    const appToken = await getAppAccessToken();

    // Check subscription status
    const { isSubscribed, tier } = await checkSubscription(appToken, profile.twitch_user_id);

    console.log(`Subscription status: ${isSubscribed ? `subscribed (tier ${tier})` : 'not subscribed'}`);

    // Create service role client for updates
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Update premium status
    await updatePremiumStatus(supabaseAdmin, user.id, isSubscribed);

    return new Response(
      JSON.stringify({
        success: true,
        isLinked: true,
        isSubscribed: isSubscribed,
        tier: tier,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error checking Twitch subscription:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to check subscription status',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
