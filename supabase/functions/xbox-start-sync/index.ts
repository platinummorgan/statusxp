import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const RAILWAY_URL = 'https://statusxp-production.up.railway.app';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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
      .select('xbox_refresh_token, xbox_xuid, xbox_user_hash, xbox_access_token, xbox_sync_status')
      .eq('id', user.id)
      .single();

    if (!profile?.xbox_refresh_token) {
      return new Response(JSON.stringify({ error: 'Xbox account not linked' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (profile.xbox_sync_status === 'syncing') {
      return new Response(JSON.stringify({ error: 'Sync already in progress' }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Mark all old pending syncs as failed
    await supabase
      .from('xbox_sync_logs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: 'Sync abandoned - new sync started',
      })
      .eq('user_id', user.id)
      .eq('status', 'pending');

    // Create new sync log
    const { data: syncLog } = await supabase
      .from('xbox_sync_logs')
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
        xbox_sync_status: 'syncing',
        xbox_sync_progress: 0,
        xbox_sync_error: null,
      })
      .eq('id', user.id);

    // Call Railway service - it will handle everything
    const railwayPayload = {
      userId: user.id,
      xuid: profile.xbox_xuid,
      userHash: profile.xbox_user_hash,
      accessToken: profile.xbox_access_token,
      refreshToken: profile.xbox_refresh_token,
      syncLogId: syncLog.id,
      // Allow a test batchSize - defaults to small to reduce memory usage in Railway
      batchSize: 5,
      maxConcurrent: 1,
    };

    console.log('Calling Railway /sync/xbox with payload size:', JSON.stringify(railwayPayload).length);
    let railwayResponse;
    try {
      const headers: Record<string, string> = { 'Content-Type': 'application/json' };
      
      // Add auth header if SYNC_SERVICE_SECRET is configured
      const syncSecret = Deno.env.get('SYNC_SERVICE_SECRET');
      if (syncSecret) {
        headers['Authorization'] = `Bearer ${syncSecret}`;
      }
      
      railwayResponse = await fetch(`${RAILWAY_URL}/sync/xbox`, {
        method: 'POST',
        headers,
        body: JSON.stringify(railwayPayload),
      });
    } catch (fetchError) {
      console.error('Network error when calling Railway /sync/xbox:', fetchError);
      throw new Error('Failed to start sync on Railway (network error)');
    }

    const railwayBody = await railwayResponse.text().catch(() => null);
    console.log('Railway start response:', railwayResponse.status, railwayBody?.slice?.(0, 200));
    if (!railwayResponse.ok) {
      console.error('Failed to start sync on Railway:', railwayResponse.status, railwayBody);
      throw new Error('Failed to start sync on Railway');
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Xbox sync started',
        syncLogId: syncLog.id,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Xbox sync start error:', error);
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
