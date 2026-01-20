/**
 * PSN Sync Status Edge Function
 * 
 * Returns the current status of PSN trophy sync
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

    // Get sync status from profile
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('psn_sync_status, psn_sync_progress, psn_sync_error, last_psn_sync_at, psn_account_id')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Get latest sync log
    const { data: latestLog } = await supabase
      .from('psn_sync_log')
      .select('*')
      .eq('user_id', user.id)
      .order('started_at', { ascending: false })
      .limit(1)
      .single();

    // Calculate time since last sync
    let lastSyncText = null;
    if (profile.last_psn_sync_at) {
      const lastSync = new Date(profile.last_psn_sync_at);
      const now = new Date();
      const diffMs = now.getTime() - lastSync.getTime();
      const diffMins = Math.floor(diffMs / 60000);
      const diffHours = Math.floor(diffMins / 60);
      const diffDays = Math.floor(diffHours / 24);

      if (diffMins < 1) {
        lastSyncText = 'Just now';
      } else if (diffMins < 60) {
        lastSyncText = `${diffMins} minute${diffMins > 1 ? 's' : ''} ago`;
      } else if (diffHours < 24) {
        lastSyncText = `${diffHours} hour${diffHours > 1 ? 's' : ''} ago`;
      } else {
        lastSyncText = `${diffDays} day${diffDays > 1 ? 's' : ''} ago`;
      }
    }

    const response = {
      isLinked: !!profile.psn_account_id,
      status: profile.psn_sync_status,
      progress: profile.psn_sync_progress,
      error: profile.psn_sync_error,
      lastSyncAt: profile.last_psn_sync_at,
      lastSyncText,
      latestLog: latestLog ? {
        id: latestLog.id,
        syncType: latestLog.sync_type,
        status: latestLog.status,
        gamesProcessed: latestLog.games_processed,
        gamesTotal: latestLog.games_total,
        trophiesAdded: latestLog.trophies_added,
        trophiesUpdated: latestLog.trophies_updated,
        startedAt: latestLog.started_at,
        completedAt: latestLog.completed_at,
        errorMessage: latestLog.error_message,
      } : null,
    };

    return new Response(JSON.stringify(response), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Error getting sync status:', error);
    return new Response(
      JSON.stringify({
        error: error.message || 'Failed to get sync status',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
