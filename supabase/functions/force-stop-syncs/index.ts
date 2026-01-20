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
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Force stop all running syncs
    console.log('Force stopping all running syncs...');

    // Update all profiles with running syncs
    const { error: profileError } = await supabase
      .from('profiles')
      .update({
        psn_sync_status: 'stopped',
        psn_sync_progress: 0,
        xbox_sync_status: 'stopped', 
        xbox_sync_progress: 0,
        steam_sync_status: 'stopped',
        steam_sync_progress: 0,
      })
      .or('psn_sync_status.eq.syncing,psn_sync_status.eq.cancelling,xbox_sync_status.eq.syncing,xbox_sync_status.eq.cancelling,steam_sync_status.eq.syncing,steam_sync_status.eq.cancelling');

    if (profileError) {
      console.error('Profile update error:', profileError);
    }

    // Cancel pending sync logs
    const now = new Date().toISOString();
    
    await supabase
      .from('psn_sync_logs')
      .update({ status: 'cancelled', completed_at: now })
      .in('status', ['pending', 'syncing']);
      
    await supabase
      .from('xbox_sync_logs')
      .update({ status: 'cancelled', completed_at: now })
      .in('status', ['pending', 'syncing']);
      
    await supabase
      .from('steam_sync_logs')
      .update({ status: 'cancelled', completed_at: now })
      .in('status', ['pending', 'syncing']);

    console.log('✅ All syncs force-stopped successfully');

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'All running syncs have been force-stopped' 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Force stop error:', error);
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