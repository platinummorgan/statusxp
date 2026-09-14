import { reconcileTwitchSubscription } from '../_shared/twitch-reconcile.ts';
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

    // Create service role client for updating profiles
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    // Only a Twitch identity obtained through this OAuth exchange may bind.
    const { error: bindingError } = await supabaseAdmin.rpc('bind_verified_twitch_account', {
      p_user_id: user.id,
      p_twitch_user_id: twitchUser.id,
    });
    if (bindingError) {
      const conflict = bindingError.code === '23505' || bindingError.message === 'Twitch account already linked';
      return new Response(JSON.stringify({ error: conflict
        ? 'Account already linked. Disconnect the existing Twitch account first.'
        : 'Unable to save Twitch link. Please try again.' }), {
        status: conflict ? 409 : 503,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Linking and entitlement verification have separate outcomes. A temporary
    // provider failure must not require reusing an already-consumed OAuth code.
    let isSubscribed: boolean | null = null;
    let subscriptionCheckPending = false;
    try {
      isSubscribed = await reconcileTwitchSubscription(twitchUser.id);
    } catch {
      subscriptionCheckPending = true;
    }

    console.log('Twitch account linked successfully!');

    return new Response(
      JSON.stringify({
        success: true,
        twitchUserId: twitchUser.id,
        twitchUsername: twitchUser.login,
        twitchDisplayName: twitchUser.display_name,
        isSubscribed: isSubscribed,
        subscriptionCheckPending,
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
