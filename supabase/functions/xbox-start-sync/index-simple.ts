import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Get authenticated user
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    );

    const { data: { user } } = await supabaseClient.auth.getUser();
    if (!user) {
      return new Response(
        JSON.stringify({ error: 'Not authenticated' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Get user profile with service role client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

    const { data: profile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', user.id)
      .single();

    if (!profile?.xbox_xuid) {
      return new Response(
        JSON.stringify({ error: 'Xbox account not linked' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Refresh Xbox token
    const tokenResponse = await fetch('https://login.live.com/oauth20_token.srf', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: Deno.env.get('XBOX_CLIENT_ID')!,
        refresh_token: profile.xbox_refresh_token,
        grant_type: 'refresh_token',
        scope: 'Xboxlive.signin Xboxlive.offline_access',
      }),
    });

    if (!tokenResponse.ok) {
      return new Response(
        JSON.stringify({ error: 'Failed to refresh Xbox token' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    const tokens = await tokenResponse.json();
    const accessToken = tokens.access_token;

    // Update tokens
    await supabase
      .from('profiles')
      .update({
        xbox_access_token: accessToken,
        xbox_refresh_token: tokens.refresh_token,
      })
      .eq('id', user.id);

    // Create sync log
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

    // Call Railway sync service
    const syncServiceUrl = Deno.env.get('SYNC_SERVICE_URL')!;
    const syncResponse = await fetch(`${syncServiceUrl}/sync/xbox`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        userId: user.id,
        xuid: profile.xbox_xuid,
        userHash: profile.xbox_user_hash,
        accessToken: accessToken,
        syncLogId: syncLog.id,
      }),
    });

    if (!syncResponse.ok) {
      throw new Error('Failed to start sync on Railway service');
    }

    return new Response(
      JSON.stringify({
        success: true,
        syncLogId: syncLog.id,
        message: 'Xbox sync started successfully',
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: error instanceof Error ? error.message : 'Unknown error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
