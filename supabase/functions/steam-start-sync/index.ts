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
      .select('steam_id, steam_api_key, steam_sync_status')
      .eq('id', user.id)
      .single();

    if (!profile?.steam_id || !profile?.steam_api_key) {
      return new Response(JSON.stringify({ error: 'Steam account not linked' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (profile.steam_sync_status === 'syncing') {
      return new Response(JSON.stringify({ error: 'Sync already in progress' }), {
        status: 409,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Mark all old pending syncs as failed
    await supabase
      .from('steam_sync_logs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: 'Sync abandoned - new sync started',
      })
      .eq('user_id', user.id)
      .eq('status', 'pending');

    // Create new sync log
    const { data: syncLog } = await supabase
      .from('steam_sync_logs')
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
        steam_sync_status: 'syncing',
        steam_sync_progress: 0,
        steam_sync_error: null,
      })
      .eq('id', user.id);

    // Call Railway service
    const railwayResponse = await fetch(`${RAILWAY_URL}/sync/steam`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: user.id,
        steamId: profile.steam_id,
        apiKey: profile.steam_api_key,
        syncLogId: syncLog.id,
      }),
    });

    const railwayText = await railwayResponse.text().catch(() => null);
    console.log('Railway STEAM start response:', railwayResponse.status, railwayText?.slice?.(0,200));
    if (!railwayResponse.ok) {
      console.error('Failed to start STEAM sync on Railway:', railwayResponse.status, railwayText);
      throw new Error('Failed to start sync on Railway');
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Steam sync started',
        syncLogId: syncLog.id,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Steam sync start error:', error);
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
