/**
 * Delete Account Edge Function
 * 
 * Permanently deletes a user's account and all associated data.
 * This is required by Apple App Store guidelines for apps with account creation.
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
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '', // Need admin privileges
    );

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    // Get the authenticated user
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Unauthorized' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 401 }
      );
    }

    const userId = user.id;
    console.log(`🗑️ Deleting account for user: ${userId}`);

    // Delete data in order (respecting foreign key constraints)
    
    // 1. Delete AI-related data
    await supabaseAdmin.from('user_ai_guides').delete().eq('user_id', userId);
    await supabaseAdmin.from('user_ai_daily_usage').delete().eq('user_id', userId);
    await supabaseAdmin.from('user_ai_pack_purchases').delete().eq('user_id', userId);
    await supabaseAdmin.from('user_ai_credits').delete().eq('user_id', userId);
    
    // 2. Delete sync history
    await supabaseAdmin.from('user_sync_history').delete().eq('user_id', userId);
    await supabaseAdmin.from('psn_sync_logs').delete().eq('user_id', userId);
    await supabaseAdmin.from('xbox_sync_logs').delete().eq('user_id', userId);
    
    // 3. Delete display case and flex room
    await supabaseAdmin.from('display_case_items').delete().eq('user_id', userId);
    await supabaseAdmin.from('flex_room_data').delete().eq('user_id', userId);
    
    // 4. Delete meta achievements
    await supabaseAdmin.from('user_meta_achievements').delete().eq('user_id', userId);
    
    // 5. Delete user achievements/trophies
    await supabaseAdmin.from('user_trophies').delete().eq('user_id', userId);
    await supabaseAdmin.from('user_achievements').delete().eq('user_id', userId);
    
    // 6. Delete user games
    await supabaseAdmin.from('user_games').delete().eq('user_id', userId);
    
    // 7. Delete platform-specific data
    await supabaseAdmin.from('psn_user_trophy_profile').delete().eq('user_id', userId);
    await supabaseAdmin.from('user_premium_status').delete().eq('user_id', userId);
    
    // 8. Delete leaderboard cache
    await supabaseAdmin.from('leaderboard_cache').delete().eq('user_id', userId);
    
    // 9. Delete profile
    await supabaseAdmin.from('profiles').delete().eq('id', userId);
    
    // 10. Delete auth user (requires admin privileges)
    const { error: deleteAuthError } = await supabaseAdmin.auth.admin.deleteUser(userId);
    
    if (deleteAuthError) {
      console.error('Error deleting auth user:', deleteAuthError);
      throw new Error(`Failed to delete authentication account: ${deleteAuthError.message}`);
    }

    console.log(`✅ Successfully deleted account for user: ${userId}`);

    return new Response(
      JSON.stringify({ 
        success: true,
        message: 'Account successfully deleted'
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error deleting account:', error);
    
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : 'An error occurred while deleting the account'
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500 }
    );
  }
});
