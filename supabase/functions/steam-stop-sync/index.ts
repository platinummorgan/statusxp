/**
 * Steam Stop Sync Edge Function
 * 
 * Stops the current Steam sync by forwarding to sync service
 */

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

    // Forward to sync service to handle graceful cancellation
    const syncServiceUrl = Deno.env.get('SYNC_SERVICE_URL') || 'https://statusxp-sync-production.up.railway.app';
    
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    
    // Add auth header if SYNC_SERVICE_SECRET is configured
    const syncSecret = Deno.env.get('SYNC_SERVICE_SECRET');
    console.log('🔐 STEAM STOP SYNC_SERVICE_SECRET present:', !!syncSecret);
    if (syncSecret) {
      headers['Authorization'] = `Bearer ${syncSecret}`;
      console.log('🔐 STEAM STOP Authorization header set');
    } else {
      console.log('🔐 STEAM STOP No SYNC_SERVICE_SECRET found - no auth header sent');
    }
    
    const response = await fetch(`${syncServiceUrl}/sync/steam/stop`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ userId: user.id }),
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Failed to stop sync');
    }

    return new Response(
      JSON.stringify({ success: true, message: 'Steam sync stopped' }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('Error stopping Steam sync:', error);
    return new Response(
      JSON.stringify({ error: (error as Error).message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
