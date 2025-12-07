import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
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
    } = await supabaseClient.auth.getUser();

    if (!user) {
      throw new Error('Not authenticated');
    }

    // Get user profile
    const { data: profile } = await supabaseClient
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
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    );

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

    const tokens = await tokenResponse.json();
    const accessToken = tokens.access_token;

    // Update tokens in database
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
    await fetch(`${syncServiceUrl}/sync/xbox`, {
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
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
