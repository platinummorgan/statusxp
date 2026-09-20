/**
 * Activity Feed Snapshot Manager
 * 
 * Creates before/after snapshots and detects changes for activity feed
 */

import { createServiceClient } from './supabase-client.js';
import { buildVerifiedChange, readAllPages } from './activity-feed-facts.js';
import { generateActivityStory } from './activity-feed-generator.js';

const supabase = createServiceClient();

const SOURCE_PLATFORM_IDS = Object.freeze({
  psn: [1, 2, 5, 9],
  xbox: [10, 11, 12],
  steam: [4],
});

/**
 * Create pre-sync snapshot
 */
export async function createPreSyncSnapshot(userId) {
  try {
    // Get current StatusXP from leaderboard_cache
    const { data: leaderboardData, error: leaderboardError } = await supabase
      .from('leaderboard_cache')
      .select('total_statusxp')
      .eq('user_id', userId)
      .maybeSingle();
    
    if (leaderboardError) {
      console.error('❌ Failed to fetch leaderboard data for snapshot:', leaderboardError);
      return null;
    }
    
    const totalStatusXp = leaderboardData?.total_statusxp || 0;
    
    // Count PSN trophies by type (need to JOIN with achievements to get trophy type from metadata)
    const { data: psnTrophies, error: trophyError } = await supabase.rpc('get_user_trophy_counts', { p_user_id: userId });
    
    if (trophyError || !psnTrophies?.[0] ||
      !['platinum_count', 'gold_count', 'silver_count', 'bronze_count'].every(key =>
        psnTrophies[0][key] !== null && psnTrophies[0][key] !== undefined &&
        Number.isSafeInteger(Number(psnTrophies[0][key])) && Number(psnTrophies[0][key]) >= 0)) {
      console.warn('Skipping feed snapshot: trophy counts unavailable', trophyError?.message);
      return null;
    }
    const platinumCount = psnTrophies?.[0]?.platinum_count || 0;
    const goldCount = psnTrophies?.[0]?.gold_count || 0;
    const silverCount = psnTrophies?.[0]?.silver_count || 0;
    const bronzeCount = psnTrophies?.[0]?.bronze_count || 0;
    
    // Get Xbox gamerscore (if linked).
    // V2 schema stores per-title gamerscore in user_progress.current_score and
    // uses platform IDs 10/11/12 (Xbox 360 / One / Series X|S).
    const xboxProgressRows = await readAllPages(() => supabase
      .from('user_progress').select('platform_id,platform_game_id,current_score')
      .eq('user_id', userId).in('platform_id', [10, 11, 12])
      .order('platform_id').order('platform_game_id'));

    const totalGamerscore = (xboxProgressRows || []).reduce((sum, row) => {
      return sum + (Number(row?.current_score) || 0);
    }, 0);
    
    // Get Steam achievement count (if linked).
    // user_achievements has no synthetic "id" in V2 schema, so count by PK column.
    const { count: steamCount, error: steamCountError } = await supabase
      .from('user_achievements')
      .select('platform_achievement_id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('platform_id', 4); // Steam

    if (steamCountError || !Number.isSafeInteger(steamCount) || steamCount < 0) {
      console.error('⚠️ Failed to fetch Steam achievement count for snapshot:', steamCountError?.message);
      return null;
    }
    
    // Insert snapshot
    const { data: snapshot, error } = await supabase
      .from('user_stat_snapshots')
      .insert({
        user_id: userId,
        total_statusxp: totalStatusXp,
        platinum_count: platinumCount || 0,
        psn_gold_count: goldCount,
        psn_silver_count: silverCount,
        psn_bronze_count: bronzeCount,
        gamerscore: totalGamerscore,
        steam_achievement_count: steamCount || 0,
      })
      .select()
      .single();
    
    if (error) {
      console.error('❌ Failed to create snapshot:', error);
      return null;
    }
    
    console.log('📸 Created pre-sync snapshot for user:', userId);
    return snapshot;
    
  } catch (err) {
    console.error('❌ Snapshot creation error:', err);
    return null;
  }
}

/**
 * Create post-sync snapshot (same as pre-sync but after data changes)
 */
export async function createPostSyncSnapshot(userId) {
  return createPreSyncSnapshot(userId);
}

/**
 * Detect changes between snapshots and generate activity stories
 */
export async function detectChangesAndGenerateStories(userId, preSnapshot, options = {}) {
  if (!preSnapshot) {
    console.log('ℹ️  No pre-snapshot, skipping activity feed generation');
    return;
  }
  
  // Create post-snapshot
  const postSnapshot = await createPostSyncSnapshot(userId);
  if (!postSnapshot) {
    console.error('❌ Failed to create post-snapshot');
    return;
  }

  const source = options.syncSource;
  if (!SOURCE_PLATFORM_IDS[source]) return;
  try {
    const rows = await readAllPages(() => supabase.from('user_achievements')
      .select('platform_id,platform_game_id,platform_achievement_id,earned_at,synced_at,achievements(name,is_platinum,rarity_global,score_value,metadata)')
      .eq('user_id', userId).in('platform_id', SOURCE_PLATFORM_IDS[source])
      .gte('synced_at', preSnapshot.synced_at).lte('synced_at', postSnapshot.synced_at)
      .order('platform_id').order('platform_game_id').order('platform_achievement_id'));
    if (!rows.length) return;
    const gameIds = [...new Set(rows.map(row => row.platform_game_id))];
    const games = [];
    for (let i = 0; i < gameIds.length; i += 100) {
      games.push(...await readAllPages(() => supabase.from('games')
        .select('platform_id,platform_game_id,name')
        .in('platform_id', SOURCE_PLATFORM_IDS[source])
        .in('platform_game_id', gameIds.slice(i, i + 100))
        .order('platform_id').order('platform_game_id')));
    }
    const change = buildVerifiedChange(source, preSnapshot, postSnapshot, rows, games);
    if (!change) {
      console.warn('Feed skipped: no change or snapshot totals do not match imported achievements');
      return;
    }
    await generateAndInsertStory(userId, change, postSnapshot);
  } catch (error) {
    console.warn('Feed skipped: could not verify achievement context:', error.message);
  }
}

/**
 * Generate AI story and insert into activity_feed
 */
async function generateAndInsertStory(userId, change, snapshot) {
  try {
    // Get display name
    const username = await getDisplayName(userId, change.type);
    
    // Get avatar URL
    const { data: profile } = await supabase
      .from('profiles')
      .select('avatar_url')
      .eq('id', userId)
      .single();
    
    const eventDate = new Date().toISOString().split('T')[0];
    const expiresAt = new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0];
    const { data: recentStories, error: recentError } = await supabase.from('activity_feed')
      .select('id,event_type,old_value,new_value,game_title,story_text')
      .eq('user_id', userId).gte('created_at', new Date(Date.now() - 7 * 86400000).toISOString())
      .order('created_at', { ascending: false }).limit(50);
    if (recentError) throw recentError;
    if (recentStories.some(story => story.event_type === change.type &&
      story.old_value === change.oldValue && story.new_value === change.newValue &&
      story.game_title === change.gameTitle)) return;
    const result = await generateActivityStory(username, change, {
      recentStories: recentStories.slice(0, 5).map(story => story.story_text),
    });

    // Insert into activity_feed
    const { error } = await supabase
      .from('activity_feed')
      .insert({
        user_id: userId,
        story_text: result.story,
        event_type: change.type,
        change_type: change.changeType,
        old_value: change.oldValue,
        new_value: change.newValue,
        change_amount: change.change,
        game_title: change.gameTitle,
        gold_count: change.goldCount || 0,
        silver_count: change.silverCount || 0,
        bronze_count: change.bronzeCount || 0,
        username: username,
        avatar_url: profile?.avatar_url,
        event_date: eventDate,
        expires_at: expiresAt,
        ai_model: result.model,
        generation_failed: !result.success,
      });
    
    if (error) {
      console.error('❌ Failed to insert activity story:', error);
    } else {
      console.log(`✅ Generated activity story: ${change.type} for ${username}`);
    }
    
  } catch (err) {
    console.error('❌ Story generation error:', err);
  }
}

/**
 * Get appropriate display name based on event type
 */
async function getDisplayName(userId, eventType) {
  const { data: profile } = await supabase
    .from('profiles')
    .select('psn_online_id, xbox_gamertag, steam_display_name, username, preferred_display_platform')
    .eq('id', userId)
    .single();
  
  if (!profile) return 'Unknown User';
  
  // Use platform-specific name based on event type
  if (eventType === 'platinum_milestone' || eventType === 'trophy_detail' || eventType === 'trophy_with_statusxp') {
    return profile.psn_online_id || profile.username || 'PSN User';
  }
  
  if (eventType === 'gamerscore_gain') {
    return profile.xbox_gamertag || profile.username || 'Xbox User';
  }
  
  if (eventType === 'steam_achievement_gain') {
    return profile.steam_display_name || profile.username || 'Steam User';
  }
  
  // StatusXP general events - use preferred display platform if set
  if (profile.preferred_display_platform === 'psn' && profile.psn_online_id) {
    return profile.psn_online_id;
  }
  if (profile.preferred_display_platform === 'xbox' && profile.xbox_gamertag) {
    return profile.xbox_gamertag;
  }
  if (profile.preferred_display_platform === 'steam' && profile.steam_display_name) {
    return profile.steam_display_name;
  }
  
  // Fallback: use any available platform name
  return profile.psn_online_id || profile.xbox_gamertag || profile.steam_display_name || profile.username || 'User';
}
