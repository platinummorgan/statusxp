/**
 * Twitch Link Account Edge Function
 * 
 * Exchanges Twitch OAuth code for user info and links to StatusXP profile
 * Also checks subscription status and grants premium if user is subscribed
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface LinkAccountRequest {
  code: string;
  redirectUri: string;
}

interface TwitchTokenResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
}

interface TwitchUserResponse {
  data: Array<{
    id: string;
    login: string;
    display_name: string;
    profile_image_url: string;
  }>;
}

interface TwitchSubscriptionCheckResponse {
  data: Array<{
    broadcaster_id: string;
    tier: string;
  }>;
}

/**
 * Exchange Twitch OAuth code for access token
 */
async function exchangeCodeForToken(code: string, redirectUri: string): Promise<TwitchTokenResponse> {
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
      code: code,
      grant_type: 'authorization_code',
      redirect_uri: redirectUri,
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    console.error('Twitch token exchange failed:', error);
    throw new Error('Failed to exchange Twitch code for token');
  }

  return await response.json();
}

/**
 * Get Twitch user info using access token
 */
async function getTwitchUser(accessToken: string): Promise<TwitchUserResponse> {
  const clientId = Deno.env.get('TWITCH_CLIENT_ID');

  const response = await fetch('https://api.twitch.tv/helix/users', {
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Client-Id': clientId!,
    },
  });

  if (!response.ok) {
    const error = await response.text();
    console.error('Failed to fetch Twitch user:', error);
    throw new Error('Failed to fetch Twitch user info');
  }

  return await response.json();
}

/**
 * Check if user is subscribed to broadcaster
 */
async function checkSubscription(accessToken: string, userId: string): Promise<boolean> {
  const clientId = Deno.env.get('TWITCH_CLIENT_ID');
  const broadcasterId = Deno.env.get('TWITCH_BROADCASTER_ID');

  if (!broadcasterId) {
    console.log('TWITCH_BROADCASTER_ID not set, skipping subscription check');
    return false;
  }

  try {
    const response = await fetch(
      `https://api.twitch.tv/helix/subscriptions/user?broadcaster_id=${broadcasterId}&user_id=${userId}`,
      {
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Client-Id': clientId!,
        },
      }
    );

    if (response.status === 404) {
      // User is not subscribed
      return false;
    }

    if (!response.ok) {
      const error = await response.text();
      console.error('Failed to check subscription:', error);
      return false;
    }

    const data: TwitchSubscriptionCheckResponse = await response.json();
    return data.data && data.data.length > 0;
  } catch (error) {
    console.error('Error checking subscription:', error);
    return false;
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

    // Parse request body
    const { code, redirectUri }: LinkAccountRequest = await req.json();

    if (!code || !redirectUri) {
      throw new Error('Missing code or redirectUri');
    }

    console.log('Exchanging Twitch code for token...');

    // Exchange code for token
    const tokenResponse = await exchangeCodeForToken(code, redirectUri);

    console.log('Fetching Twitch user info...');

    // Get user info
    const userResponse = await getTwitchUser(tokenResponse.access_token);
    const twitchUser = userResponse.data[0];

    if (!twitchUser) {
      throw new Error('Failed to get Twitch user info');
    }

    console.log(`Twitch user: ${twitchUser.display_name} (${twitchUser.id})`);

    // Check if this Twitch account is already linked to another user
    const { data: existingProfile } = await supabaseClient
      .from('profiles')
      .select('id')
      .eq('twitch_user_id', twitchUser.id)
      .neq('id', user.id)
      .single();

    if (existingProfile) {
      return new Response(
        JSON.stringify({
          error: 'Twitch account already linked',
          message: 'This Twitch account is already connected to another StatusXP account.',
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 409 }
      );
    }

    console.log('Checking subscription status...');

    // Check subscription status
    const isSubscribed = await checkSubscription(tokenResponse.access_token, twitchUser.id);

    console.log(`Subscription status: ${isSubscribed ? 'subscribed' : 'not subscribed'}`);

    // Calculate token expiry
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + tokenResponse.expires_in);

    // Create service role client for updating profiles
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Update profile with Twitch info
    const { error: updateError } = await supabaseAdmin
      .from('profiles')
      .update({
        twitch_user_id: twitchUser.id,
      })
      .eq('id', user.id);

    if (updateError) {
      console.error('Failed to update profile:', updateError);
      throw updateError;
    }

    // If subscribed, grant premium access
    if (isSubscribed) {
      console.log('User is subscribed - granting premium access');
      
      // Calculate expiry (1 month from now)
      const premiumExpiresAt = new Date();
      premiumExpiresAt.setMonth(premiumExpiresAt.getMonth() + 1);

      const { error: premiumError } = await supabaseAdmin
        .from('user_premium_status')
        .upsert({
          user_id: user.id,
          is_premium: true,
          premium_source: 'twitch',
          expires_at: premiumExpiresAt.toISOString(),
          updated_at: new Date().toISOString(),
        }, {
          onConflict: 'user_id',
        });

      if (premiumError) {
        console.error('Failed to update premium status:', premiumError);
        // Don't fail the entire request if premium update fails
      }
    }

    console.log('Twitch account linked successfully!');

    return new Response(
      JSON.stringify({
        success: true,
        twitchUserId: twitchUser.id,
        twitchUsername: twitchUser.login,
        twitchDisplayName: twitchUser.display_name,
        isSubscribed: isSubscribed,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error linking Twitch account:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to link Twitch account',
      }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
