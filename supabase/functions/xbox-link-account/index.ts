/**
 * Xbox Link Account Edge Function
 * 
 * Exchanges Microsoft OAuth code for Xbox Live credentials and links to user profile
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  checkForExistingPlatformAccount,
  mergeUserAccounts,
} from '../_shared/account-merge.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface LinkAccountRequest {
  authCode?: string;
  accessToken?: string;
}

interface XboxLiveAuthResponse {
  xuid: string;
  gamertag: string;
  gamerscore: number;
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

/**
 * Exchange Microsoft authorization code for access token
 */
async function exchangeCodeForToken(authCode: string): Promise<string> {
  const clientId = Deno.env.get('XBOX_CLIENT_ID') ?? '000000004C12AE6F';
  const tokenResponse = await fetch('https://login.live.com/oauth20_token.srf', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      client_id: clientId,
      code: authCode,
      grant_type: 'authorization_code',
      redirect_uri: 'https://login.live.com/oauth20_desktop.srf',
    }).toString(),
  });

  if (!tokenResponse.ok) {
    const errorText = await tokenResponse.text();
    console.error('Token exchange failed:', errorText);
    throw new Error(`Failed to exchange code for token: ${errorText}`);
  }

  const tokenData = await tokenResponse.json();
  return {
    accessToken: tokenData.access_token,
    refreshToken: tokenData.refresh_token,
  };
}

/**
 * Authenticate with Xbox Live using Microsoft access token
 * This is a multi-step process:
 * 1. Get user token from Microsoft access token
 * 2. Get XSTS token from user token
 * 3. Authenticate with Xbox Live
 */
async function authenticateXboxLive(microsoftAccessToken: string): Promise<XboxLiveAuthResponse> {
  // Step 1: Authenticate with Xbox Live to get user token
  const userTokenResponse = await fetch('https://user.auth.xboxlive.com/user/authenticate', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-xbl-contract-version': '1',
    },
    body: JSON.stringify({
      RelyingParty: 'http://auth.xboxlive.com',
      TokenType: 'JWT',
      Properties: {
        AuthMethod: 'RPS',
        SiteName: 'user.auth.xboxlive.com',
        RpsTicket: `d=${microsoftAccessToken}`,
      },
    }),
  });

  if (!userTokenResponse.ok) {
    throw new Error('Failed to get Xbox Live user token');
  }

  const userTokenData = await userTokenResponse.json();
  const userToken = userTokenData.Token;

  // Step 2: Get XSTS token
  const xstsTokenResponse = await fetch('https://xsts.auth.xboxlive.com/xsts/authorize', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-xbl-contract-version': '1',
    },
    body: JSON.stringify({
      RelyingParty: 'http://xboxlive.com',
      TokenType: 'JWT',
      Properties: {
        UserTokens: [userToken],
        SandboxId: 'RETAIL',
      },
    }),
  });

  if (!xstsTokenResponse.ok) {
    const errorData = await xstsTokenResponse.json();
    console.error('XSTS token error:', errorData);
    throw new Error(`Failed to get XSTS token: ${errorData.XErr || 'Unknown error'}`);
  }

  const xstsData = await xstsTokenResponse.json();
  const xstsToken = xstsData.Token;
  const userHash = xstsData.DisplayClaims.xui[0].uhs;
  const xuid = xstsData.DisplayClaims.xui[0].xid;

  // Step 3: Get user profile and gamerscore
  const profileResponse = await fetch(`https://profile.xboxlive.com/users/xuid(${xuid})/profile/settings`, {
    method: 'GET',
    headers: {
      'x-xbl-contract-version': '3',
      Authorization: `XBL3.0 x=${userHash};${xstsToken}`,
    },
  });

  if (!profileResponse.ok) {
    throw new Error('Failed to get Xbox profile');
  }

  const profileData = await profileResponse.json();
  const settings = profileData.profileUsers[0].settings;
  
  const gamertag = settings.find((s: any) => s.id === 'Gamertag')?.value || 'Unknown';
  const gamerscore = parseInt(settings.find((s: any) => s.id === 'Gamerscore')?.value || '0', 10);

  return {
    xuid,
    gamertag,
    gamerscore,
    userHash,
    accessToken: xstsToken,
    refreshToken: userToken, // Store user token as refresh token
    expiresIn: 86400, // Xbox tokens typically last 24 hours
  };
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get user from auth header
    const supabase = createClient(
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
    } = await supabase.auth.getUser();

    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Parse request body
    const { authCode, accessToken }: LinkAccountRequest = await req.json();

    if (!authCode && !accessToken) {
      return new Response(JSON.stringify({ error: 'Authorization code or access token required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Exchange auth code for access token if needed
    let msAccessToken = accessToken;
    let msRefreshToken = '';
    
    if (authCode && !accessToken) {
      console.log('Exchanging authorization code for access token...');
      const tokens = await exchangeCodeForToken(authCode);
      msAccessToken = tokens.accessToken;
      msRefreshToken = tokens.refreshToken;
    }

    console.log('Authenticating with Xbox Live...');
    const xboxAuth = await authenticateXboxLive(msAccessToken!);
    
    // Use the Microsoft refresh token, not the Xbox user token
    xboxAuth.refreshToken = msRefreshToken;

    console.log('Getting total achievements count...');
    // Get total achievements from Xbox profile
    const achievementsResponse = await fetch(
      `https://achievements.xboxlive.com/users/xuid(${xboxAuth.xuid})/achievements`,
      {
        headers: {
          'x-xbl-contract-version': '2',
          Authorization: `XBL3.0 x=${xboxAuth.xuid};${xboxAuth.accessToken}`,
        },
      }
    );

    let totalAchievements = 0;
    if (achievementsResponse.ok) {
      const achievementsData = await achievementsResponse.json();
      totalAchievements = achievementsData.achievements?.length || 0;
    }

    console.log('Storing Xbox credentials...');
    
    // Check if this Xbox account already exists for a different user
    const mergeCheck = await checkForExistingPlatformAccount(
      supabase,
      user.id,
      'xbox',
      xboxAuth.xuid  // Use XUID instead of gamertag - this is the unique identifier
    );

    if (mergeCheck.shouldMerge && mergeCheck.existingUserId) {
      console.log(`🔗 Xbox account ${xboxAuth.gamertag} already exists under user ${mergeCheck.existingUserId}`);
      
      return new Response(
        JSON.stringify({
          error: 'Xbox account already registered',
          platform: 'Xbox',
          username: xboxAuth.gamertag,
          xuid: xboxAuth.xuid,
          message: `This Xbox account (XUID: ${xboxAuth.xuid}) is already connected to another account. If this is your account, please contact support for assistance.`,
        }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 409 }
      );
    }
    
    // Calculate token expiry
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + xboxAuth.expiresIn);

    // Update user profile with Xbox credentials
    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        xbox_xuid: xboxAuth.xuid,
        xbox_gamertag: xboxAuth.gamertag,
        xbox_user_hash: xboxAuth.userHash,
        xbox_access_token: xboxAuth.accessToken,
        xbox_refresh_token: xboxAuth.refreshToken,
        xbox_token_expires_at: expiresAt.toISOString(),
        xbox_sync_status: 'never_synced',
      })
      .eq('id', user.id);

    if (updateError) {
      throw updateError;
    }

    console.log('Xbox account linked successfully!');

    return new Response(
      JSON.stringify({
        success: true,
        xuid: xboxAuth.xuid,
        gamertag: xboxAuth.gamertag,
        gamerscore: xboxAuth.gamerscore,
        totalAchievements,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error linking Xbox account:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to link Xbox account',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
