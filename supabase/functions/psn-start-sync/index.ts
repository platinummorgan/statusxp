import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { exchangeRefreshTokenForAuthTokens } from '../_shared/psn-api.ts';

const RAILWAY_URL = 'https://statusxp-production.up.railway.app';
const PSN_RELINK_ERROR_MESSAGE =
  'PlayStation session expired. Disconnect and reconnect PlayStation in Settings, then sync again.';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function extractErrorText(error: unknown): string {
  if (!error) return '';
  if (typeof error === 'string') return error;
  if (error instanceof Error) return error.message || String(error);
  try {
    return JSON.stringify(error);
  } catch {
    return String(error);
  }
}

function isPsnRelinkRequired(message: unknown): boolean {
  if (typeof message !== 'string' || message.trim().length === 0) {
    return false;
  }

  const lower = message.toLowerCase();
  const tokenMarkers = [
    'invalid_grant',
    'invalid client',
    'invalid_client',
    'refresh token',
    'token expired',
    'expired token',
    'jwt expired',
    'oauth token',
    'unauthorized',
    'forbidden',
    '401',
    '403',
    'relink',
    'reauthorize',
  ];

  return (
    tokenMarkers.some((marker) => lower.includes(marker)) ||
    (lower.includes('bad request') &&
      (lower.includes('exchange') || lower.includes('auth') || lower.includes('token')))
  );
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization')!;
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await supabase.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Get profile
    const { data: profile } = await supabase
      .from('profiles')
      .select('psn_account_id, psn_access_token, psn_refresh_token, psn_sync_status')
      .eq('id', user.id)
      .single();

    if (!profile?.psn_account_id) {
      return new Response(JSON.stringify({ error: 'PSN account not linked' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!profile.psn_refresh_token) {
      await supabase
        .from('profiles')
        .update({
          psn_sync_status: 'error',
          psn_sync_error: PSN_RELINK_ERROR_MESSAGE,
        })
        .eq('id', user.id);

      return new Response(
        JSON.stringify({ error: PSN_RELINK_ERROR_MESSAGE, requiresRelink: true }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    if (profile.psn_sync_status === 'syncing') {
      return new Response(JSON.stringify({ error: 'Sync already in progress' }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Preflight token refresh so we fail fast with a clear relink message
    // instead of reporting "sync started" when PSN credentials are expired.
    let refreshedAccessToken = profile.psn_access_token;
    let refreshedRefreshToken = profile.psn_refresh_token;
    try {
      const refreshed = await exchangeRefreshTokenForAuthTokens(profile.psn_refresh_token);
      refreshedAccessToken = refreshed.accessToken;
      refreshedRefreshToken = refreshed.refreshToken || profile.psn_refresh_token;
    } catch (tokenError) {
      const tokenErrorText = extractErrorText(tokenError);
      const needsRelink = isPsnRelinkRequired(tokenErrorText);
      const normalizedError = needsRelink
        ? PSN_RELINK_ERROR_MESSAGE
        : `Failed to refresh PlayStation session: ${tokenErrorText || 'Unknown error'}`;

      await supabase
        .from('profiles')
        .update({
          psn_sync_status: 'error',
          psn_sync_error: normalizedError,
        })
        .eq('id', user.id);

      return new Response(
        JSON.stringify({ error: normalizedError, requiresRelink: needsRelink }),
        {
          status: needsRelink ? 400 : 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Persist fresh tokens before dispatching the long-running sync worker.
    await supabase
      .from('profiles')
      .update({
        psn_access_token: refreshedAccessToken,
        psn_refresh_token: refreshedRefreshToken,
      })
      .eq('id', user.id);

    // Mark all old pending syncs as failed
    await supabase
      .from('psn_sync_logs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: 'Sync abandoned - new sync started',
      })
      .eq('user_id', user.id)
      .eq('status', 'pending');

    // Create new sync log
    const { data: syncLog } = await supabase
      .from('psn_sync_logs')
      .insert({
        user_id: user.id,
        sync_type: 'full',
        status: 'pending',
        started_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (!syncLog) {
      throw new Error('Failed to create sync log');
    }

    // Set profile to syncing
    await supabase
      .from('profiles')
      .update({
        psn_sync_status: 'syncing',
        psn_sync_progress: 0,
        psn_sync_error: null,
      })
      .eq('id', user.id);

    // Call Railway service
    const railwayPayload = {
      userId: user.id,
      accountId: profile.psn_account_id,
      accessToken: refreshedAccessToken,
      refreshToken: refreshedRefreshToken,
      syncLogId: syncLog.id,
      batchSize: 5,
      maxConcurrent: 1,
    };
    console.log('Calling Railway /sync/psn with payload size:', JSON.stringify(railwayPayload).length);
    let railwayResponse;
    try {
      const headers: Record<string, string> = { 'Content-Type': 'application/json' };
      
      // Add auth header if SYNC_SERVICE_SECRET is configured
      const syncSecret = Deno.env.get('SYNC_SERVICE_SECRET');
      console.log('🔐 PSN SYNC_SERVICE_SECRET present:', !!syncSecret);
      console.log('🔐 PSN SYNC_SERVICE_SECRET value:', syncSecret ? '[SET]' : '[NOT SET]');
      if (syncSecret) {
        headers['Authorization'] = `Bearer ${syncSecret}`;
        console.log('🔐 PSN Authorization header set:', `Bearer ${syncSecret.substring(0, 3)}...`);
      } else {
        console.log('🔐 PSN No SYNC_SERVICE_SECRET found - no auth header sent');
      }
      
      railwayResponse = await fetch(`${RAILWAY_URL}/sync/psn`, {
        method: 'POST',
        headers,
        body: JSON.stringify(railwayPayload),
      });
    } catch (fetchError) {
      console.error('Network error when calling Railway /sync/psn:', fetchError);
      const normalizedError = 'Failed to start sync on Railway (network error)';
      await supabase
        .from('profiles')
        .update({
          psn_sync_status: 'error',
          psn_sync_error: normalizedError,
        })
        .eq('id', user.id);
      await supabase
        .from('psn_sync_logs')
        .update({
          status: 'failed',
          completed_at: new Date().toISOString(),
          error_message: normalizedError,
        })
        .eq('id', syncLog.id);
      throw new Error('Failed to start sync on Railway (network error)');
    }
    const railwayText = await railwayResponse.text().catch(() => null);
    console.log('Railway PSN start response:', railwayResponse.status, railwayText?.slice?.(0, 200));
    if (!railwayResponse.ok) {
      console.error('Failed to start PSN sync on Railway:', railwayResponse.status, railwayText);
      const normalizedError = 'Failed to start sync on Railway';
      await supabase
        .from('profiles')
        .update({
          psn_sync_status: 'error',
          psn_sync_error: normalizedError,
        })
        .eq('id', user.id);
      await supabase
        .from('psn_sync_logs')
        .update({
          status: 'failed',
          completed_at: new Date().toISOString(),
          error_message: normalizedError,
        })
        .eq('id', syncLog.id);
      throw new Error('Failed to start sync on Railway');
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'PSN sync started',
        syncLogId: syncLog.id,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('PSN sync start error:', error);
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : 'Unknown error' 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
