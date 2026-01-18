/**
 * Xbox Stop Sync Edge Function
 * 
 * Stops an in-progress Xbox achievement sync by forwarding to sync service
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
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const authHeader = req.headers.get('Authorization')!;

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

    // Forward to sync service to handle graceful cancellation
    const syncServiceUrl = Deno.env.get('SYNC_SERVICE_URL') || 'https://statusxp-sync-production.up.railway.app';
    
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    
    // Add auth header if SYNC_SERVICE_SECRET is configured
    const syncSecret = Deno.env.get('SYNC_SERVICE_SECRET');
    console.log('🔐 XBOX STOP SYNC_SERVICE_SECRET present:', !!syncSecret);
    if (syncSecret) {
      headers['Authorization'] = `Bearer ${syncSecret}`;
      console.log('🔐 XBOX STOP Authorization header set');
    } else {
      console.log('🔐 XBOX STOP No SYNC_SERVICE_SECRET found - no auth header sent');
    }
    
    const response = await fetch(`${syncServiceUrl}/sync/xbox/stop`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ userId: user.id }),
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || 'Failed to stop sync');
    }

    return new Response(
      JSON.stringify({
        success: true,
        message: 'Sync stop requested successfully',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error stopping Xbox sync:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to stop Xbox sync',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
