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
  getUserTrophyProfileSummary,
  getUserProfile,
} from '../_shared/psn-api.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface LinkAccountRequest {
  npssoToken: string;
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

    console.log('Fetching PSN profile...');
    const profile = await getUserTrophyProfileSummary(authorization, 'me');
    
    console.log('Fetching PSN user profile (onlineId, avatar, Plus status)...');
    const userProfile = await getUserProfile(authorization, 'me');

    console.log('Storing PSN credentials...');
    
    // Calculate token expiry
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + (authorization.expiresIn || 3600));

    // Update user profile with PSN credentials
    const { error: updateError } = await supabase
      .from('profiles')
      .update({
        psn_account_id: profile.accountId,
        psn_online_id: userProfile.onlineId,
        psn_avatar_url: userProfile.avatarUrls.find(a => a.size === 'm')?.avatarUrl || userProfile.avatarUrls[0]?.avatarUrl,
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

    // Store PSN trophy profile
    await supabase
      .from('psn_user_trophy_profile')
      .upsert({
        user_id: user.id,
        psn_trophy_level: parseInt(profile.trophyLevel.toString()),
        psn_trophy_progress: profile.progress,
        psn_trophy_tier: profile.tier,
        psn_earned_bronze: profile.earnedTrophies.bronze,
        psn_earned_silver: profile.earnedTrophies.silver,
        psn_earned_gold: profile.earnedTrophies.gold,
        psn_earned_platinum: profile.earnedTrophies.platinum,
      });

    return new Response(
      JSON.stringify({
        success: true,
        accountId: profile.accountId,
        onlineId: userProfile.onlineId,
        avatarUrl: userProfile.avatarUrls.find(a => a.size === 'm')?.avatarUrl,
        isPlus: userProfile.isPlus,
        trophyLevel: profile.trophyLevel,
        totalTrophies: 
          profile.earnedTrophies.bronze +
          profile.earnedTrophies.silver +
          profile.earnedTrophies.gold +
          profile.earnedTrophies.platinum,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error linking PSN account:', error);
    return new Response(
      JSON.stringify({
        error: error.message || 'Failed to link PSN account',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
