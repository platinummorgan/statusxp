/**
 * Account Merging Logic
 * 
 * Handles merging user accounts when a gaming platform username is detected
 * as already existing in the database under a different Supabase auth user.
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

export interface MergeResult {
  shouldMerge: boolean;
  existingUserId?: string;
  platform: string;
  platformUsername: string;
}

/**
 * Check if a gaming platform username already exists for a different user
 */
export async function checkForExistingPlatformAccount(
  supabase: SupabaseClient,
  currentUserId: string,
  platform: 'psn' | 'xbox' | 'steam',
  platformUsername: string
): Promise<MergeResult> {
  let query;
  
  switch (platform) {
    case 'psn':
      query = supabase
        .from('profiles')
        .select('id')
        .eq('psn_online_id', platformUsername)
        .neq('id', currentUserId)
        .single();
      break;
    case 'xbox':
      query = supabase
        .from('profiles')
        .select('id')
        .eq('xbox_gamertag', platformUsername)
        .neq('id', currentUserId)
        .single();
      break;
    case 'steam':
      query = supabase
        .from('profiles')
        .select('id')
        .eq('steam_id', platformUsername)
        .neq('id', currentUserId)
        .single();
      break;
  }

  const { data: existingProfile, error } = await query;

  if (error || !existingProfile) {
    return {
      shouldMerge: false,
      platform,
      platformUsername,
    };
  }

  return {
    shouldMerge: true,
    existingUserId: existingProfile.id,
    platform,
    platformUsername,
  };
}

/**
 * Merge all gaming data from oldUserId to newUserId
 */
export async function mergeUserAccounts(
  supabase: SupabaseClient,
  oldUserId: string,
  newUserId: string
): Promise<void> {
  console.log(`🔄 Merging accounts: ${oldUserId} → ${newUserId}`);

  try {
    // 1. Merge user_games
    const { data: oldGames } = await supabase
      .from('user_games')
      .select('*')
      .eq('user_id', oldUserId);

    if (oldGames && oldGames.length > 0) {
      for (const game of oldGames) {
        // Check if new user already has this game
        const { data: existing } = await supabase
          .from('user_games')
          .select('id')
          .eq('user_id', newUserId)
          .eq('game_title_id', game.game_title_id)
          .single();

        if (!existing) {
          // Transfer game to new user
          await supabase
            .from('user_games')
            .update({ user_id: newUserId })
            .eq('id', game.id);
        }
      }
    }

    // 2. Merge user_achievements
    const { data: oldAchievements } = await supabase
      .from('user_achievements')
      .select('*')
      .eq('user_id', oldUserId);

    if (oldAchievements && oldAchievements.length > 0) {
      for (const achievement of oldAchievements) {
        const { data: existing } = await supabase
          .from('user_achievements')
          .select('id')
          .eq('user_id', newUserId)
          .eq('achievement_id', achievement.achievement_id)
          .single();

        if (!existing) {
          await supabase
            .from('user_achievements')
            .update({ user_id: newUserId })
            .eq('id', achievement.id);
        }
      }
    }

    // 3. Merge virtual_completions (if table exists)
    const { data: oldCompletions } = await supabase
      .from('virtual_completions')
      .select('*')
      .eq('user_id', oldUserId);

    if (oldCompletions && oldCompletions.length > 0) {
      for (const completion of oldCompletions) {
        const { data: existing } = await supabase
          .from('virtual_completions')
          .select('id')
          .eq('user_id', newUserId)
          .eq('game_title_id', completion.game_title_id)
          .eq('platform', completion.platform)
          .single();

        if (!existing) {
          await supabase
            .from('virtual_completions')
            .update({ user_id: newUserId })
            .eq('id', completion.id);
        }
      }
    }

    // 4. Copy platform tokens/credentials to new profile
    const { data: oldProfile } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', oldUserId)
      .single();

    if (oldProfile) {
      const updates: any = {};
      
      // Copy PSN credentials if they exist
      if (oldProfile.psn_account_id) {
        updates.psn_account_id = oldProfile.psn_account_id;
        updates.psn_online_id = oldProfile.psn_online_id;
        updates.psn_npsso_token = oldProfile.psn_npsso_token;
        updates.psn_access_token = oldProfile.psn_access_token;
        updates.psn_refresh_token = oldProfile.psn_refresh_token;
        updates.psn_token_expires_at = oldProfile.psn_token_expires_at;
        updates.psn_sync_status = oldProfile.psn_sync_status;
        updates.last_psn_sync_at = oldProfile.last_psn_sync_at;
      }

      // Copy Xbox credentials
      if (oldProfile.xbox_xuid) {
        updates.xbox_xuid = oldProfile.xbox_xuid;
        updates.xbox_gamertag = oldProfile.xbox_gamertag;
        updates.xbox_user_hash = oldProfile.xbox_user_hash;
        updates.xbox_access_token = oldProfile.xbox_access_token;
        updates.xbox_refresh_token = oldProfile.xbox_refresh_token;
        updates.xbox_token_expires_at = oldProfile.xbox_token_expires_at;
        updates.xbox_sync_status = oldProfile.xbox_sync_status;
        updates.last_xbox_sync_at = oldProfile.last_xbox_sync_at;
      }

      // Copy Steam credentials
      if (oldProfile.steam_id) {
        updates.steam_id = oldProfile.steam_id;
        updates.steam_api_key = oldProfile.steam_api_key;
        updates.steam_sync_status = oldProfile.steam_sync_status;
        updates.last_steam_sync_at = oldProfile.last_steam_sync_at;
      }

      if (Object.keys(updates).length > 0) {
        await supabase
          .from('profiles')
          .update(updates)
          .eq('id', newUserId);
      }
    }

    // 5. Delete old user_games and user_achievements (already moved)
    await supabase.from('user_games').delete().eq('user_id', oldUserId);
    await supabase.from('user_achievements').delete().eq('user_id', oldUserId);
    await supabase.from('virtual_completions').delete().eq('user_id', oldUserId);

    // 6. Mark old profile as merged
    await supabase
      .from('profiles')
      .update({
        psn_account_id: null,
        psn_online_id: null,
        xbox_xuid: null,
        xbox_gamertag: null,
        steam_id: null,
        merged_into_user_id: newUserId,
        merged_at: new Date().toISOString(),
      })
      .eq('id', oldUserId);

    console.log(`✅ Account merge complete: ${oldUserId} → ${newUserId}`);
  } catch (error) {
    console.error('❌ Error merging accounts:', error);
    throw error;
  }
}
