/**
 * Xbox Sync Status Edge Function
 * 
 * Returns current Xbox sync status for authenticated user
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  // Handle CORS
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

    // Get user profile with Xbox sync status
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('xbox_xuid, xbox_sync_status, xbox_sync_progress, xbox_sync_error, last_xbox_sync_at')
      .eq('id', user.id)
      .single();

    if (profileError) {
      throw profileError;
    }

    const isLinked = !!profile.xbox_xuid;

    // Get latest sync log (try both table names for compatibility)
    let latestLog = null;
    try {
      const { data } = await supabase
        .from('xbox_sync_logs')
        .select('*')
        .eq('user_id', user.id)
        .order('started_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      latestLog = data;
    } catch (e) {
      // Try singular table name if plural doesn't exist
      const { data } = await supabase
        .from('xbox_sync_log')
        .select('*')
        .eq('user_id', user.id)
        .order('started_at', { ascending: false })
        .limit(1)
        .maybeSingle();
      latestLog = data;
    }

    // Format last sync time
    let lastSyncText = null;
    if (profile.last_xbox_sync_at) {
      const lastSync = new Date(profile.last_xbox_sync_at);
      const now = new Date();
      const diffMs = now.getTime() - lastSync.getTime();
      const diffMins = Math.floor(diffMs / 60000);
      const diffHours = Math.floor(diffMs / 3600000);
      const diffDays = Math.floor(diffMs / 86400000);

      if (diffMins < 1) {
        lastSyncText = 'Just now';
      } else if (diffMins < 60) {
        lastSyncText = `${diffMins} minute${diffMins !== 1 ? 's' : ''} ago`;
      } else if (diffHours < 24) {
        lastSyncText = `${diffHours} hour${diffHours !== 1 ? 's' : ''} ago`;
      } else {
        lastSyncText = `${diffDays} day${diffDays !== 1 ? 's' : ''} ago`;
      }
    }

    return new Response(
      JSON.stringify({
        isLinked,
        status: profile.xbox_sync_status || 'never_synced',
        progress: profile.xbox_sync_progress || 0,
        error: profile.xbox_sync_error,
        lastSyncAt: profile.last_xbox_sync_at,
        lastSyncText,
        latestLog: latestLog ? {
          id: latestLog.id,
          syncType: latestLog.sync_type,
          status: latestLog.status,
          gamesProcessed: latestLog.games_processed,
          gamesTotal: latestLog.games_total,
          achievementsAdded: latestLog.achievements_added,
          achievementsUpdated: latestLog.achievements_updated,
          startedAt: latestLog.started_at,
          completedAt: latestLog.completed_at,
          errorMessage: latestLog.error_message,
        } : null,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error getting Xbox sync status:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to get sync status',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
