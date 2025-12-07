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
      .select('psn_account_id, psn_access_token, psn_refresh_token, psn_sync_status')
      .eq('id', user.id)
      .single();

    if (!profile?.psn_access_token) {
      return new Response(JSON.stringify({ error: 'PSN account not linked' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (profile.psn_sync_status === 'syncing') {
      return new Response(JSON.stringify({ error: 'Sync already in progress' }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

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
    const railwayResponse = await fetch(`${RAILWAY_URL}/sync/psn`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: user.id,
        accountId: profile.psn_account_id,
        accessToken: profile.psn_access_token,
        refreshToken: profile.psn_refresh_token,
        syncLogId: syncLog.id,
      }),
    });

    if (!railwayResponse.ok) {
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
