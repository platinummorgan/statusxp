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
    console.log(`Deleting account for user: ${userId}`);

    // Execute a delete and enforce failures, except optional legacy relations that may not exist.
    const deleteBy = async (
      table: string,
      column: string,
      value: string,
      options: { optionalMissingRelation?: boolean } = {},
    ) => {
      const { error } = await supabaseAdmin.from(table).delete().eq(column, value);
      if (!error) return;

      const isMissingRelation =
        error.code === '42P01' ||
        error.code === 'PGRST205' ||
        /does not exist/i.test(error.message ?? '') ||
        /could not find/i.test(error.message ?? '');

      if (options.optionalMissingRelation && isMissingRelation) {
        console.warn(`Skipping missing optional relation: ${table}`);
        return;
      }

      throw new Error(`Failed deleting from ${table}: ${error.message}`);
    };

    // Delete data in order (respecting foreign key constraints)
    
    // 1. Delete AI-related data
    await deleteBy('user_ai_guides', 'user_id', userId, { optionalMissingRelation: true });
    await deleteBy('user_ai_daily_usage', 'user_id', userId);
    await deleteBy('user_ai_pack_purchases', 'user_id', userId);
    await deleteBy('user_ai_credits', 'user_id', userId);
    
    // 2. Delete sync history
    await deleteBy('user_sync_history', 'user_id', userId);
    await deleteBy('psn_sync_logs', 'user_id', userId);
    await deleteBy('xbox_sync_logs', 'user_id', userId);
    
    // 3. Delete flex room data
    await deleteBy('flex_room_data', 'profile_id', userId); // Uses profile_id
    
    // 4. Delete meta achievements
    await deleteBy('user_meta_achievements', 'user_id', userId);
    
    // 5. Delete user achievements/trophies
    await deleteBy('user_trophies', 'user_id', userId, { optionalMissingRelation: true });
    await deleteBy('user_achievements', 'user_id', userId);
    
    // 6. Delete user game progress (source table behind user_games view)
    await deleteBy('user_progress', 'user_id', userId);
    
    // 7. Delete platform-specific data
    await deleteBy('psn_user_trophy_profile', 'user_id', userId, { optionalMissingRelation: true });
    await deleteBy('user_premium_status', 'user_id', userId);
    
    // 8. Delete leaderboard cache
    await deleteBy('leaderboard_cache', 'user_id', userId);
    await deleteBy('notifications', 'user_id', userId, { optionalMissingRelation: true });
    
    // 9. Delete profile
    await deleteBy('profiles', 'id', userId);
    
    // 10. Delete auth user (requires admin privileges)
    const { error: deleteAuthError } = await supabaseAdmin.auth.admin.deleteUser(userId);
    
    if (deleteAuthError) {
      console.error('Error deleting auth user:', deleteAuthError);
      throw new Error(`Failed to delete authentication account: ${deleteAuthError.message}`);
    }

    console.log(`Successfully deleted account for user: ${userId}`);

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
