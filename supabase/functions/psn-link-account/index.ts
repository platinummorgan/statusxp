/**
 * PSN Link Account Edge Function
 * 
 * Exchanges NPSSO token for PSN credentials and links to user profile
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  exchangeNpssoForAccessCode,
  exchangeAccessCodeForAuthTokens,
  extractAccountIdFromAccessToken,
  getUserTrophyProfileSummary,
  getUserProfile,
  type PSNUserProfile,
  type UserTrophyProfileSummary,
} from '../_shared/psn-api.ts';
import {
  checkForExistingPlatformAccount,
} from '../_shared/account-merge.ts';
import { uploadExternalAvatar } from '../_shared/avatar-storage.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface LinkAccountRequest {
  npssoToken: string;
}

function extractErrorMessage(error: unknown): string {
  if (!error) return '';
  if (error instanceof Error) return error.message;
  if (typeof error === 'string') return error;

  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

function normalizeAccountId(accountId: string | null | undefined): string | null {
  const normalized = accountId?.trim();
  if (!normalized || normalized.toLowerCase() === 'me') return null;
  return normalized;
}

function getTotalTrophies(profile: UserTrophyProfileSummary | null): number {
  if (!profile) return 0;

  return (
    Number(profile.earnedTrophies?.bronze || 0) +
    Number(profile.earnedTrophies?.silver || 0) +
    Number(profile.earnedTrophies?.gold || 0) +
    Number(profile.earnedTrophies?.platinum || 0)
  );
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
    const { npssoToken }: LinkAccountRequest = await req.json();

    if (!npssoToken) {
      return new Response(JSON.stringify({ error: 'NPSSO token required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log('Exchanging NPSSO for access code...');
    const accessCode = await exchangeNpssoForAccessCode(npssoToken);

    console.log('Exchanging access code for auth tokens...');
    const authorization = await exchangeAccessCodeForAuthTokens(accessCode);

    console.log('Fetching PSN user profile (onlineId, avatar, Plus status)...');
    let userProfile: PSNUserProfile | null = null;
    try {
      userProfile = await getUserProfile(authorization, 'me');
    } catch (profileError) {
      console.warn('Failed to fetch PSN user profile:', extractErrorMessage(profileError));
    }

    let accountId =
      normalizeAccountId(userProfile?.accountId) ||
      extractAccountIdFromAccessToken(authorization.accessToken);

    console.log('Fetching PSN trophy profile summary...');
    let trophyProfile: UserTrophyProfileSummary | null = null;
    let trophySummaryError: string | null = null;
    try {
      trophyProfile = await getUserTrophyProfileSummary(authorization, accountId || 'me');
      accountId = normalizeAccountId(trophyProfile.accountId) || accountId;
    } catch (summaryError) {
      trophySummaryError = extractErrorMessage(summaryError);
      console.warn('Failed to fetch PSN trophy profile summary; continuing link:', trophySummaryError);
    }

    if (!accountId) {
      throw new Error(
        trophySummaryError
          ? `Failed to resolve PSN account ID after authentication. Trophy summary error: ${trophySummaryError}`
          : 'Failed to resolve PSN account ID after authentication.'
      );
    }

    if (!userProfile) {
      // Keep link behavior compatible with the previous fallback when profile
      // details are private or temporarily unavailable.
      userProfile = {
        onlineId: accountId,
        accountId,
        npId: '',
        avatarUrls: [],
        plus: 0,
        isPlus: false,
        aboutMe: '',
        languagesUsed: [],
        isOfficiallyVerified: false,
      };
    }

    const onlineId = userProfile.onlineId || accountId;

    console.log('Storing PSN credentials...');
    
    // First check: Does THIS user already have PSN linked?
    // Use service role to bypass RLS for reading user's own profile
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );
    
    const { data: currentUserProfile } = await supabaseAdmin
      .from('profiles')
      .select('psn_online_id')
      .eq('id', user.id)
      .single();
    
    const userAlreadyHasPSN = currentUserProfile?.psn_online_id === onlineId;
    
    if (userAlreadyHasPSN) {
      console.log(`🔄 Refreshing PSN tokens for user ${user.id} (same PSN: ${onlineId})`);
      // Continue to update - this is just a token refresh
    } else {
      // Check if this PSN account exists for a DIFFERENT user
      const mergeCheck = await checkForExistingPlatformAccount(
        supabase,
        user.id,
        'psn',
        onlineId
      );

      if (mergeCheck.shouldMerge && mergeCheck.existingUserId) {
        console.log(`🔗 PSN account ${onlineId} already exists under user ${mergeCheck.existingUserId}`);
        
        return new Response(
          JSON.stringify({
            error: 'PSN account already registered',
            platform: 'PSN',
            username: onlineId,
            accountId,
            message: `This PSN account (Account ID: ${accountId}) is already connected to another account. If this is your account, please contact support for assistance.`,
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 409 }
        );
      }
    }
    
    // Calculate token expiry
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + (authorization.expiresIn || 3600));

    // Download and upload PSN avatar to Supabase Storage to avoid CORS issues
    const externalAvatarUrl = userProfile.avatarUrls?.find(a => a.size === 'm')?.avatarUrl || userProfile.avatarUrls?.[0]?.avatarUrl;
    let avatarUrl = null;
    
    if (externalAvatarUrl) {
      console.log('Proxying PSN avatar through Supabase Storage...');
      // Use service role client for storage operations
      const serviceSupabase = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      );
      const proxiedUrl = await uploadExternalAvatar(serviceSupabase, externalAvatarUrl, user.id, 'psn');
      if (proxiedUrl) {
        avatarUrl = proxiedUrl;
        console.log('Successfully proxied PSN avatar:', proxiedUrl);
      } else {
        console.warn('Failed to proxy PSN avatar');
      }
    }

    // Update user profile with PSN credentials
    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        psn_account_id: accountId,
        psn_online_id: onlineId,
        psn_avatar_url: avatarUrl,
        psn_is_plus: userProfile.isPlus,
        psn_npsso_token: npssoToken, // In production, this should be encrypted
        psn_access_token: authorization.accessToken,
        psn_refresh_token: authorization.refreshToken,
        psn_token_expires_at: expiresAt.toISOString(),
        psn_sync_status: 'never_synced',
      })
      .eq('id', user.id);

    if (updateError) {
      throw updateError;
    }

    // Store PSN trophy profile when Sony returned it. Linking should still
    // succeed if this optional summary endpoint is temporarily unavailable.
    if (trophyProfile) {
      await supabase
        .from('psn_user_trophy_profile')
        .upsert({
          user_id: user.id,
          psn_trophy_level: parseInt(trophyProfile.trophyLevel.toString()),
          psn_trophy_progress: trophyProfile.progress,
          psn_trophy_tier: trophyProfile.tier,
          psn_earned_bronze: trophyProfile.earnedTrophies.bronze,
          psn_earned_silver: trophyProfile.earnedTrophies.silver,
          psn_earned_gold: trophyProfile.earnedTrophies.gold,
          psn_earned_platinum: trophyProfile.earnedTrophies.platinum,
          last_fetched_at: new Date().toISOString(),
        });
    }

    return new Response(
      JSON.stringify({
        success: true,
        accountId,
        onlineId,
        avatarUrl: avatarUrl || externalAvatarUrl || null,
        isPlus: userProfile.isPlus,
        trophyLevel: trophyProfile ? parseInt(trophyProfile.trophyLevel.toString()) : 0,
        totalTrophies: getTotalTrophies(trophyProfile),
        trophySummaryAvailable: !!trophyProfile,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error linking PSN account:', error);
    return new Response(
      JSON.stringify({
        error: (error as Error).message || 'Failed to link PSN account',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
