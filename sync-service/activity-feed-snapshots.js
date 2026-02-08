/**
 * Activity Feed Snapshot Manager
 * 
 * Creates before/after snapshots and detects changes for activity feed
 */

import { createClient } from '@supabase/supabase-js';
import { generateActivityStory } from './activity-feed-generator.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

/**
 * Create pre-sync snapshot
 */
export async function createPreSyncSnapshot(userId) {
  try {
    // Delete any recent pre-sync snapshots to prevent duplicates from multiple sync attempts
    await supabase
      .from('user_stat_snapshots')
      .delete()
      .eq('user_id', userId)
      .gte('synced_at', new Date(Date.now() - 5 * 60 * 1000).toISOString());
    
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
    const { data: psnTrophies } = await supabase.rpc('get_user_trophy_counts', { p_user_id: userId });
    
    const platinumCount = psnTrophies?.[0]?.platinum_count || 0;
    const goldCount = psnTrophies?.[0]?.gold_count || 0;
    const silverCount = psnTrophies?.[0]?.silver_count || 0;
    const bronzeCount = psnTrophies?.[0]?.bronze_count || 0;
    
    // Get Xbox gamerscore (if linked)
    const { data: xboxData } = await supabase
      .from('user_progress')
      .select('total_gamerscore')
      .eq('user_id', userId)
      .eq('platform_id', 10) // Xbox Live
      .maybeSingle();
    
    // Get Steam achievement count (if linked)
    const { count: steamCount } = await supabase
      .from('user_achievements')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', userId)
      .eq('platform_id', 4); // Steam
    
    // Get latest game for context
    const { data: latestGame } = await supabase
      .from('user_games')
      .select('game_title, platform_id')
      .eq('user_id', userId)
     .order('last_played_at', { ascending: false })
      .limit(1)
      .maybeSingle();
    
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
        gamerscore: xboxData?.total_gamerscore || 0,
        steam_achievement_count: steamCount || 0,
        latest_game_title: latestGame?.game_title,
        latest_platform_id: latestGame?.platform_id,
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
export async function detectChangesAndGenerateStories(userId, preSnapshot) {
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
  
  // Detect all changes
  const changes = [];
  
  // StatusXP change
  if (postSnapshot.total_statusxp > preSnapshot.total_statusxp) {
    changes.push({
      type: 'statusxp_gain',
      oldValue: preSnapshot.total_statusxp,
      newValue: postSnapshot.total_statusxp,
      change: postSnapshot.total_statusxp - preSnapshot.total_statusxp,
      changeType: categorizeChange(postSnapshot.total_statusxp - preSnapshot.total_statusxp, 'statusxp'),
    });
  }
  
  // Platinum milestone
  if (postSnapshot.platinum_count > preSnapshot.platinum_count) {
    changes.push({
      type: 'platinum_milestone',
      oldValue: preSnapshot.platinum_count,
      newValue: postSnapshot.platinum_count,
      change: postSnapshot.platinum_count - preSnapshot.platinum_count,
      changeType: 'milestone',
      gameTitle: postSnapshot.latest_game_title || 'Unknown Game',
    });
  }
  
  // Trophy breakdown
  const goldDiff = postSnapshot.psn_gold_count - preSnapshot.psn_gold_count;
  const silverDiff = postSnapshot.psn_silver_count - preSnapshot.psn_silver_count;
  const bronzeDiff = postSnapshot.psn_bronze_count - preSnapshot.psn_bronze_count;
  
  if (goldDiff > 0 || silverDiff > 0 || bronzeDiff > 0) {
    changes.push({
      type: 'trophy_detail',
      goldCount: goldDiff,
      silverCount: silverDiff,
      bronzeCount: bronzeDiff,
      oldGold: preSnapshot.psn_gold_count,
      oldSilver: preSnapshot.psn_silver_count,
      oldBronze: preSnapshot.psn_bronze_count,
      gameTitle: postSnapshot.latest_game_title || 'a game',
    });
  }
  
  // Gamerscore change (Xbox)
  if (postSnapshot.gamerscore > preSnapshot.gamerscore) {
    changes.push({
      type: 'gamerscore_gain',
      oldValue: preSnapshot.gamerscore,
      newValue: postSnapshot.gamerscore,
      change: postSnapshot.gamerscore - preSnapshot.gamerscore,
      changeType: categorizeChange(postSnapshot.gamerscore - preSnapshot.gamerscore, 'gamerscore'),
    });
  }
  
  // Steam achievements
  if (postSnapshot.steam_achievement_count > preSnapshot.steam_achievement_count) {
    changes.push({
      type: 'steam_achievement_gain',
      oldValue: preSnapshot.steam_achievement_count,
      newValue: postSnapshot.steam_achievement_count,
      change: postSnapshot.steam_achievement_count - preSnapshot.steam_achievement_count,
      changeType: categorizeChange(postSnapshot.steam_achievement_count - preSnapshot.steam_achievement_count, 'steam_achievements'),
    });
  }
  
  if (changes.length === 0) {
    console.log('ℹ️  No changes detected, no stories to generate');
    return;
  }
  
  console.log(`📊 Detected ${changes.length} changes for activity feed`);
  
  // Combine trophy/achievement changes with StatusXP gains for richer stories
  const combinedChanges = combineRelatedChanges(changes);
  console.log(`✨ Combined into ${combinedChanges.length} stories`);
  
  // Generate stories for each change
  for (const change of combinedChanges) {
    await generateAndInsertStory(userId, change, postSnapshot);
  }
}

/**
 * Combine related changes (e.g., trophies + StatusXP gain) into single stories
 */
function combineRelatedChanges(changes) {
  const statusXpChange = changes.find(c => c.type === 'statusxp_gain');
  const trophyChange = changes.find(c => c.type === 'trophy_detail');
  const gamerscoreChange = changes.find(c => c.type === 'gamerscore_gain');
  const steamChange = changes.find(c => c.type === 'steam_achievement_gain');
  const platinumChange = changes.find(c => c.type === 'platinum_milestone');
  
  let combinedChanges = [];
  let processedTypes = new Set();
  
  // Combine trophy details with StatusXP gain
  if (trophyChange && statusXpChange) {
    combinedChanges.push({
      ...trophyChange,
      type: 'trophy_with_statusxp',
      statusxpOld: statusXpChange.oldValue,
      statusxpNew: statusXpChange.newValue,
      statusxpChange: statusXpChange.change,
      changeType: statusXpChange.changeType,
    });
    processedTypes.add('statusxp_gain');
    processedTypes.add('trophy_detail');
  }
  
  // Combine gamerscore with StatusXP
  if (gamerscoreChange && statusXpChange && !processedTypes.has('statusxp_gain')) {
    combinedChanges.push({
      ...gamerscoreChange,
      type: 'gamerscore_with_statusxp',
      statusxpOld: statusXpChange.oldValue,
      statusxpNew: statusXpChange.newValue,
      statusxpChange: statusXpChange.change,
    });
    processedTypes.add('statusxp_gain');
    processedTypes.add('gamerscore_gain');
  }
  
  // Combine Steam with StatusXP
  if (steamChange && statusXpChange && !processedTypes.has('statusxp_gain')) {
    combinedChanges.push({
      ...steamChange,
      type: 'steam_with_statusxp',
      statusxpOld: statusXpChange.oldValue,
      statusxpNew: statusXpChange.newValue,
      statusxpChange: statusXpChange.change,
    });
    processedTypes.add('statusxp_gain');
    processedTypes.add('steam_achievement_gain');
  }
  
  // Add remaining changes that weren't combined
  for (const change of changes) {
    if (!processedTypes.has(change.type)) {
      combinedChanges.push(change);
    }
  }
  
  return combinedChanges;
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
    
    // Generate AI story
    const result = await generateActivityStory(username, change);
    
    // Calculate expiration (7 days from today)
    const eventDate = new Date().toISOString().split('T')[0];
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    
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
  if (eventType === 'platinum_milestone' || eventType === 'trophy_detail') {
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

/**
 * Helper: Categorize change magnitude
 */
function categorizeChange(amount, type) {
  if (type === 'statusxp') {
    if (amount < 100) return 'small';
    if (amount < 500) return 'medium';
    if (amount < 1000) return 'large';
    return 'massive';
  }
  
  if (type === 'gamerscore') {
    if (amount < 100) return 'small';
    if (amount < 500) return 'medium';
    if (amount < 1000) return 'large';
    return 'massive';
  }
  
  if (type === 'steam_achievements') {
    if (amount < 10) return 'small';
    if (amount < 50) return 'medium';
    if (amount < 100) return 'large';
    return 'massive';
  }
  
  return 'medium';
}
