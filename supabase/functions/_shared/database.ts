/**
 * Database helper functions for PSN integration
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import type { TrophyTitle, Trophy, TrophyGroup, UserTrophyProfileSummary } from './psn-api.ts';

/**
 * Get or create platform by code
 */
export async function getOrCreatePlatform(
  supabase: SupabaseClient,
  platformCode: string
): Promise<number> {
  // Check if platform exists
  const { data: existing } = await supabase
    .from('platforms')
    .select('id')
    .eq('code', platformCode)
    .single();

  if (existing) {
    return existing.id;
  }

  // Create platform
  const platformNames: Record<string, string> = {
    PS5: 'PlayStation 5',
    PS4: 'PlayStation 4',
    PS3: 'PlayStation 3',
    PSVITA: 'PlayStation Vita',
  };

  const { data, error } = await supabase
    .from('platforms')
    .insert({
      code: platformCode,
      name: platformNames[platformCode] || platformCode,
    })
    .select('id')
    .single();

  if (error) throw error;
  return data!.id;
}

/**
 * Parse platform from PSN string
 */
export function parsePSNPlatform(platformString: string): string[] {
  // PSN platforms can be comma-separated like "PS4,PSVITA"
  return platformString.split(',').map(p => p.trim());
}

/**
 * Get primary platform from list
 */
export function getPrimaryPlatform(platforms: string[]): string {
  const priority = ['PS5', 'PS4', 'PS3', 'PSVITA'];
  for (const p of priority) {
    if (platforms.includes(p)) return p;
  }
  return platforms[0];
}

/**
 * Upsert game title from PSN data
 */
export async function upsertGameTitle(
  supabase: SupabaseClient,
  userId: string,
  trophyTitle: TrophyTitle
): Promise<number> {
  // Check if game exists by PSN communication ID
  const { data: existing } = await supabase
    .from('game_titles')
    .select('id')
    .eq('psn_np_communication_id', trophyTitle.npCommunicationId)
    .single();

  const platforms = parsePSNPlatform(trophyTitle.trophyTitlePlatform);
  const primaryPlatform = getPrimaryPlatform(platforms);
  const platformId = await getOrCreatePlatform(supabase, primaryPlatform);

  const gameData = {
    platform_id: platformId,
    name: trophyTitle.trophyTitleName,
    cover_url: trophyTitle.trophyTitleIconUrl,
    psn_np_communication_id: trophyTitle.npCommunicationId,
    psn_np_service_name: trophyTitle.npServiceName,
    psn_trophy_set_version: trophyTitle.trophySetVersion,
    psn_has_trophy_groups: trophyTitle.hasTrophyGroups,
    metadata: {
      psn_platforms: platforms,
      psn_title_detail: trophyTitle.trophyTitleDetail,
    },
  };

  if (existing) {
    // Update existing
    const { error } = await supabase
      .from('game_titles')
      .update(gameData)
      .eq('id', existing.id);

    if (error) throw error;
    return existing.id;
  } else {
    // Insert new
    const { data, error } = await supabase
      .from('game_titles')
      .insert(gameData)
      .select('id')
      .single();

    if (error) throw error;
    return data!.id;
  }
}

/**
 * Upsert user game progress
 */
export async function upsertUserGame(
  supabase: SupabaseClient,
  userId: string,
  gameTitleId: number,
  trophyTitle: TrophyTitle
): Promise<void> {
  const totalTrophies = 
    trophyTitle.definedTrophies.bronze +
    trophyTitle.definedTrophies.silver +
    trophyTitle.definedTrophies.gold +
    trophyTitle.definedTrophies.platinum;

  const earnedTrophies = trophyTitle.earnedTrophies
    ? trophyTitle.earnedTrophies.bronze +
      trophyTitle.earnedTrophies.silver +
      trophyTitle.earnedTrophies.gold +
      trophyTitle.earnedTrophies.platinum
    : 0;

  const completionPercent = trophyTitle.progress || 0;
  const hasPlatinum = (trophyTitle.earnedTrophies?.platinum ?? 0) > 0;
  
  // Extract individual trophy tier counts from PSN's earnedTrophies summary
  const bronzeTrophies = trophyTitle.earnedTrophies?.bronze ?? 0;
  const silverTrophies = trophyTitle.earnedTrophies?.silver ?? 0;
  const goldTrophies = trophyTitle.earnedTrophies?.gold ?? 0;
  const platinumTrophies = trophyTitle.earnedTrophies?.platinum ?? 0;

  // Get platform_id from game_titles
  const platforms = parsePSNPlatform(trophyTitle.trophyTitlePlatform);
  const primaryPlatform = getPrimaryPlatform(platforms);
  const platformId = await getOrCreatePlatform(supabase, primaryPlatform);

  console.log(`Game: ${trophyTitle.trophyTitleName}`);
  console.log(`  Raw earnedTrophies object:`, JSON.stringify(trophyTitle.earnedTrophies));
  console.log(`  Earned Plat: ${trophyTitle.earnedTrophies?.platinum ?? 0}, Has Platinum: ${hasPlatinum}`);

  const { error } = await supabase
    .from('user_games')
    .upsert({
      user_id: userId,
      game_title_id: gameTitleId,
      platform_id: platformId,
      total_trophies: totalTrophies,
      earned_trophies: earnedTrophies,
      bronze_trophies: bronzeTrophies,
      silver_trophies: silverTrophies,
      gold_trophies: goldTrophies,
      platinum_trophies: platinumTrophies,
      has_platinum: hasPlatinum,
      completion_percent: completionPercent,
      last_played_at: trophyTitle.lastUpdatedDateTime,
      psn_progress_data: {
        defined_trophies: trophyTitle.definedTrophies,
        earned_trophies: trophyTitle.earnedTrophies,
      },
      psn_last_updated_at: trophyTitle.lastUpdatedDateTime,
    }, {
      onConflict: 'user_id,game_title_id',
    });

  if (error) throw error;
}

/**
 * Upsert trophy
 */
export async function upsertTrophy(
  supabase: SupabaseClient,
  gameTitleId: number,
  trophy: Trophy,
  sortOrder: number
): Promise<number> {
  const { data: existing } = await supabase
    .from('trophies')
    .select('id')
    .eq('game_title_id', gameTitleId)
    .eq('psn_trophy_id', trophy.trophyId)
    .single();

  const trophyData = {
    game_title_id: gameTitleId,
    name: trophy.trophyName,
    description: trophy.trophyDetail,
    tier: trophy.trophyType,
    sort_order: sortOrder,
    icon_url: trophy.trophyIconUrl,
    psn_trophy_id: trophy.trophyId,
    psn_trophy_group_id: trophy.trophyGroupId,
    psn_trophy_type: trophy.trophyType,
    psn_is_secret: trophy.trophyHidden,
    psn_earn_rate: trophy.trophyEarnedRate ? parseFloat(trophy.trophyEarnedRate) : null,
    rarity_global: trophy.trophyEarnedRate ? parseFloat(trophy.trophyEarnedRate) : null,
    hidden: trophy.trophyHidden,
    metadata: {
      trophy_rare: trophy.trophyRare,
      progress_target_value: trophy.trophyProgressTargetValue,
    },
  };

  if (existing) {
    const { error } = await supabase
      .from('trophies')
      .update(trophyData)
      .eq('id', existing.id);

    if (error) throw error;
    return existing.id;
  } else {
    const { data, error } = await supabase
      .from('trophies')
      .insert(trophyData)
      .select('id')
      .single();

    if (error) throw error;
    return data!.id;
  }
}

/**
 * Upsert user trophy (earned status)
 */
export async function upsertUserTrophy(
  supabase: SupabaseClient,
  userId: string,
  trophyId: number,
  trophy: Trophy
): Promise<void> {
  if (!trophy.earned) return;

  const { error } = await supabase
    .from('user_trophies')
    .upsert({
      user_id: userId,
      trophy_id: trophyId,
      earned_at: trophy.earnedDateTime,
      source: 'psn',
    }, {
      onConflict: 'user_id,trophy_id',
    });

  if (error) throw error;
}

/**
 * Upsert trophy groups for a game
 */
export async function upsertTrophyGroups(
  supabase: SupabaseClient,
  gameTitleId: number,
  groups: TrophyGroup[]
): Promise<void> {
  for (const group of groups) {
    await supabase
      .from('psn_trophy_groups')
      .upsert({
        game_title_id: gameTitleId,
        trophy_group_id: group.trophyGroupId,
        trophy_group_name: group.trophyGroupName,
        trophy_group_detail: group.trophyGroupDetail,
        trophy_group_icon_url: group.trophyGroupIconUrl,
        trophy_count_bronze: group.definedTrophies.bronze,
        trophy_count_silver: group.definedTrophies.silver,
        trophy_count_gold: group.definedTrophies.gold,
        trophy_count_platinum: group.definedTrophies.platinum,
      }, {
        onConflict: 'game_title_id,trophy_group_id',
      });
  }
}

/**
 * Update user PSN trophy profile
 */
export async function updateUserTrophyProfile(
  supabase: SupabaseClient,
  userId: string,
  profile: UserTrophyProfileSummary
): Promise<void> {
  const { error } = await supabase
    .from('psn_user_trophy_profile')
    .upsert({
      user_id: userId,
      psn_trophy_level: parseInt(profile.trophyLevel.toString()),
      psn_trophy_progress: profile.progress,
      psn_trophy_tier: profile.tier,
      psn_earned_bronze: profile.earnedTrophies.bronze,
      psn_earned_silver: profile.earnedTrophies.silver,
      psn_earned_gold: profile.earnedTrophies.gold,
      psn_earned_platinum: profile.earnedTrophies.platinum,
      last_fetched_at: new Date().toISOString(),
    }, {
      onConflict: 'user_id',
    });

  if (error) throw error;
}

/**
 * Update user stats from trophies
 */
export async function recalculateUserStats(
  supabase: SupabaseClient,
  userId: string
): Promise<void> {
  // Get aggregated stats
  const { data: games } = await supabase
    .from('user_games')
    .select('has_platinum, completion_percent')
    .eq('user_id', userId);

  const { data: trophies } = await supabase
    .from('user_trophies')
    .select('trophy_id, trophies(rarity_global)')
    .eq('user_id', userId);

  if (!games || !trophies) return;

  const totalPlatinums = games.filter(g => g.has_platinum && g.completion_percent === 100).length;
  const totalGamesTracked = games.length;
  const totalTrophies = trophies.length;

  // Find rarest trophy
  let rarestTrophy = null;
  let rarestRarity = 100;
  for (const t of trophies) {
    const rarity = (t.trophies as any)?.rarity_global;
    if (rarity && rarity < rarestRarity) {
      rarestRarity = rarity;
      rarestTrophy = t.trophy_id;
    }
  }

  await supabase
    .from('user_stats')
    .upsert({
      user_id: userId,
      total_platinums: totalPlatinums,
      total_games_tracked: totalGamesTracked,
      total_trophies: totalTrophies,
      rarest_trophy_id: rarestTrophy,
      rarest_trophy_rarity: rarestRarity < 100 ? rarestRarity : null,
    }, {
      onConflict: 'user_id',
    });
}

/**
 * Log sync operation
 */
export async function createSyncLog(
  supabase: SupabaseClient,
  userId: string,
  syncType: 'full' | 'incremental' | 'single_game'
): Promise<number> {
  const { data, error } = await supabase
    .from('psn_sync_log')
    .insert({
      user_id: userId,
      sync_type: syncType,
      status: 'started',
    })
    .select('id')
    .single();

  if (error) throw error;
  return data!.id;
}

/**
 * Update sync log
 */
export async function updateSyncLog(
  supabase: SupabaseClient,
  logId: number,
  updates: {
    status?: 'pending' | 'in_progress' | 'completed' | 'failed' | 'stopped';
    games_processed?: number;
    games_total?: number;
    trophies_added?: number;
    trophies_updated?: number;
    error_message?: string;
  }
): Promise<void> {
  const updateData: any = { ...updates };
  
  if (updates.status === 'completed' || updates.status === 'failed' || updates.status === 'stopped') {
    updateData.completed_at = new Date().toISOString();
  }

  const { error } = await supabase
    .from('psn_sync_log')
    .update(updateData)
    .eq('id', logId);

  if (error) throw error;
}
