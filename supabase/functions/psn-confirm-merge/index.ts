/**
 * PSN Confirm Merge Edge Function
 * 
 * Confirms and executes account merge when user approves
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { mergeUserAccounts } from '../_shared/account-merge.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface ConfirmMergeRequest {
  existingUserId: string;
  credentials: any;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    const { data: { user } } = await supabase.auth.getUser();
    if (!user) {
      throw new Error('Unauthorized');
    }

    const { existingUserId, credentials }: ConfirmMergeRequest = await req.json();

    console.log(`🔄 User confirmed merge: ${existingUserId} → ${user.id}`);
    
    // Perform the merge
    await mergeUserAccounts(supabase, existingUserId, user.id);

    // Now store the PSN credentials
    const expiresAt = new Date();
    expiresAt.setSeconds(expiresAt.getSeconds() + (credentials.expiresIn || 3600));

    await supabase
      .from('profiles')
      .update({
        psn_account_id: credentials.accountId,
        psn_online_id: credentials.onlineId,
        psn_avatar_url: null, // Will be set by sync service
        psn_is_plus: credentials.isPlus,
        psn_npsso_token: credentials.npssoToken,
        psn_access_token: credentials.accessToken,
        psn_refresh_token: credentials.refreshToken,
        psn_token_expires_at: expiresAt.toISOString(),
        psn_sync_status: 'never_synced',
      })
      .eq('id', user.id);

    await supabase
      .from('psn_user_trophy_profile')
      .upsert({
        user_id: user.id,
        psn_trophy_level: credentials.trophyLevel,
        psn_trophy_tier: credentials.trophyTier,
      });

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Account merged successfully',
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error confirming merge:', error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    );
  }
});
