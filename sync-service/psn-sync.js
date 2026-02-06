// psn-sync.js (rewritten - drop-in replacement)
// Fixes:
// - NO cross-platform "duplicate prevention" that corrupts platform_id
// - Batch upserts for achievements + user_achievements (fast + consistent)
// - Earned counts derived from per-trophy earned flags (source of truth)
// - user_progress updated ONLY after trophies successfully fetched

import { createClient } from '@supabase/supabase-js';
import { uploadExternalIcon, uploadGameCover } from './icon-proxy-utils.js';
import { initIGDBValidator } from './igdb-validator.js';
import { createPreSyncSnapshot, detectChangesAndGenerateStories } from './activity-feed-snapshots.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const ENV_BATCH_SIZE = parseInt(process.env.BATCH_SIZE || '20', 10);
const ENV_MAX_CONCURRENT = parseInt(process.env.MAX_CONCURRENT || '3', 10);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Helper to download external avatar and upload to Supabase Storage
async function uploadExternalAvatar(externalUrl, userId, platform) {
  try {
    console.log(`[AVATAR STORAGE] Downloading ${platform} avatar from:`, externalUrl);
    
    // Download the image from the external URL
    const response = await fetch(externalUrl);
    if (!response.ok) {
      console.error(`[AVATAR STORAGE] Failed to download avatar: ${response.status}`);
      return null;
    }

    // Get the image data as a buffer
    const arrayBuffer = await response.arrayBuffer();
    
    // Determine file extension from content type
    const contentType = response.headers.get('content-type') || 'image/jpeg';
    let extension = 'jpg';
    if (contentType.includes('png')) extension = 'png';
    else if (contentType.includes('gif')) extension = 'gif';
    else if (contentType.includes('webp')) extension = 'webp';
    
    // Create a unique filename: user-avatars/{platform}_{userId}_{timestamp}.ext
    const timestamp = Date.now();
    const filename = `user-avatars/${platform}_${userId}_${timestamp}.${extension}`;
    
    console.log(`[AVATAR STORAGE] Uploading to Supabase Storage: ${filename}`);
    
    // Upload to Supabase Storage
    const { data, error } = await supabase.storage
      .from('avatars')
      .upload(filename, arrayBuffer, {
        contentType,
        upsert: true,
      });

    if (error) {
      console.error('[AVATAR STORAGE] Upload error:', error);
      return null;
    }

    // Get the public URL
    const { data: { publicUrl } } = supabase.storage
      .from('avatars')
      .getPublicUrl(filename);

    console.log(`[AVATAR STORAGE] Successfully uploaded avatar:`, publicUrl);
    return publicUrl;
  } catch (error) {
    console.error('[AVATAR STORAGE] Exception:', error);
    return null;
  }
}

function logMemory(label) {
  try {
    const m = process.memoryUsage();
    console.log(
      label,
      `rss=${Math.round(m.rss / 1024 / 1024)}MB`,
      `heapUsed=${Math.round(m.heapUsed / 1024 / 1024)}MB`,
      `heapTotal=${Math.round(m.heapTotal / 1024 / 1024)}MB`,
      `external=${Math.round(m.external / 1024 / 1024)}MB`
    );
  } catch (e) {
    console.log('logMemory error', e.message);
  }
}

function mapPsnPlatformToPlatformId(trophyTitlePlatformRaw) {
  const s = (trophyTitlePlatformRaw || '').toUpperCase();
  if (s.includes('PS5')) return { platformId: 1, platformVersion: 'PS5' };
  if (s.includes('PS4')) return { platformId: 2, platformVersion: 'PS4' };
  if (s.includes('PS3')) return { platformId: 5, platformVersion: 'PS3' };
  if (s.includes('VITA')) return { platformId: 9, platformVersion: 'PSVITA' };
  // Default to PS5 (safe fallback, but log it)
  return { platformId: 1, platformVersion: 'PS5' };
}

function validatePlatformMapping(trophyTitlePlatform, platformId, gameName, npCommunicationId) {
  const s = (trophyTitlePlatform || '').toUpperCase();
  
  // For cross-platform games, we pick the newest platform
  // So validation should check if assigned platform exists in the string, not exact match
  const platformMap = {
    1: 'PS5',
    2: 'PS4', 
    5: 'PS3',
    9: 'VITA'
  };
  
  const assignedPlatformName = platformMap[platformId];
  if (assignedPlatformName && !s.includes(assignedPlatformName)) {
    console.error(
      `🚨 PLATFORM MISMATCH: Assigned ${assignedPlatformName} (id=${platformId}) but not in PSN list "${trophyTitlePlatform}" | ` +
      `game="${gameName}" | npId=${npCommunicationId}`
    );
    return false;
  }
  
  return true;
}

async function updateSyncStatus(userId, updates, retries = 3) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const { error } = await supabase.from('profiles').update(updates).eq('id', userId);
      if (!error) return true;
      console.error(`❌ Status update attempt ${attempt}/${retries} failed:`, error.message);
      if (attempt < retries) await sleep(1000 * attempt);
    } catch (err) {
      console.error(`❌ Status update attempt ${attempt}/${retries} threw:`, err.message);
      if (attempt < retries) await sleep(1000 * attempt);
    }
  }
  console.error('🚨 CRITICAL: Failed to update sync status after all retries');
  return false;
}

async function isCancelled(userId) {
  const { data, error } = await supabase
    .from('profiles')
    .select('psn_sync_status')
    .eq('id', userId)
    .maybeSingle();

  if (error) throw new Error(`Profile lookup failed: ${error.message}`);
  return data?.psn_sync_status === 'cancelling';
}

function computeStatusXpFields({ rarityPercent, isPlatinum }) {
  const includeInScore = !isPlatinum;

  if (!includeInScore) {
    return { base_status_xp: 0, include_in_score: false, is_platinum: true };
  }

  // Default for NULL rarity (treat as common)
  let baseStatusXP = 0.5;

  if (rarityPercent != null && !Number.isNaN(Number(rarityPercent))) {
    const r = Number(rarityPercent);
    const floor = 0.5;
    const cap = 12;
    const p = 3;
    
    // Exponential curve: base = floor + (cap - floor) * (1 - r/100)^p
    const inv = Math.max(0, Math.min(1, 1 - (r / 100)));
    baseStatusXP = floor + (cap - floor) * Math.pow(inv, p);
    
    // Clamp to range
    baseStatusXP = Math.max(floor, Math.min(cap, baseStatusXP));
  }

  return { base_status_xp: baseStatusXP, include_in_score: true, is_platinum: false };
}

async function upsertGame({ platformId, platformVersion, title }) {
  const trimmedTitle = (title.trophyTitleName || '').trim();

  // Proxy the game cover through Supabase Storage
  const externalCoverUrl = title.trophyTitleIconUrl || null;
  const proxiedCoverUrl = externalCoverUrl
    ? await uploadGameCover(externalCoverUrl, platformId, title.npCommunicationId, supabase)
    : null;

  // Build base payload
  const payload = {
    platform_id: platformId,
    platform_game_id: title.npCommunicationId,
    name: trimmedTitle || 'Unknown Title',
    metadata: {
      psn_np_communication_id: title.npCommunicationId,
      platform_version: platformVersion,
      np_service_name: title.npServiceName || null,
      trophy_set_version: title.trophySetVersion || null,
      has_trophy_groups: !!title.hasTrophyGroups,
      trophy_group_count: title.trophyGroupCount ?? null,
      last_api_seen_at: new Date().toISOString(),
    },
  };

  // Only set cover_url if we have a new value (don't overwrite existing with null)
  const newCoverUrl = proxiedCoverUrl || externalCoverUrl;
  if (newCoverUrl) {
    payload.cover_url = newCoverUrl;
  }

  const { data, error } = await supabase
    .from('games')
    .upsert(payload, { onConflict: 'platform_id,platform_game_id' })
    .select('platform_id, platform_game_id, name')
    .single();

  if (error) throw new Error(`Failed to upsert game "${trimmedTitle}": ${error.message}`);
  return data;
}

async function upsertAchievementsBatch({ platformId, platformVersion, gameId, trophies, userTrophyMap, trophyGroupMap }) {
  if (!trophies?.length) return;

  // First, fetch existing achievements to check for valid proxied URLs
  const trophyIds = trophies.map(t => t.trophyId.toString());
  const { data: existingAchievements } = await supabase
    .from('achievements')
    .select('platform_achievement_id, proxied_icon_url')
    .eq('platform_id', platformId)
    .eq('platform_game_id', gameId)
    .in('platform_achievement_id', trophyIds);

  // Create map of existing proxied URLs
  const existingProxiedMap = new Map();
  if (existingAchievements) {
    for (const ach of existingAchievements) {
      existingProxiedMap.set(ach.platform_achievement_id, ach.proxied_icon_url);
    }
  }

  // Helper to check if proxied URL is valid (not NULL, not numbered folder, not timestamped, matches achievement ID)
  const isValidProxiedUrl = (url, achievementId) => {
    if (!url) return false;
    // Must be in correct folder structure: /avatars/achievement-icons/psn/
    if (!url.includes('/avatars/achievement-icons/psn/')) return false;
    // Must NOT be numbered folder: /avatars/achievement-icons/1/ etc
    if (/\/avatars\/achievement-icons\/\d+\//.test(url)) return false;
    // Must NOT have timestamp: filename_1234567890123.png
    if (/_\d{13}\.(png|jpg|jpeg|gif|webp)$/i.test(url)) return false;
    // Filename must match gameId_achievementId pattern: ends with /{gameId}_{achievementId}.ext
    const filePattern = new RegExp(`/${gameId}_${achievementId}\\.(png|jpg|jpeg|gif|webp)$`, 'i');
    if (!filePattern.test(url)) return false;
    // Valid!
    return true;
  };

  // NOTE: we still proxy icons one-by-one (storage), but DB writes are batched.
  const rows = [];
  for (const trophyMeta of trophies) {
    const userTrophy = userTrophyMap.get(trophyMeta.trophyId);

    const isPlatinum = trophyMeta.trophyType === 'platinum';
    const rarityPercent = userTrophy?.trophyEarnedRate ? parseFloat(userTrophy.trophyEarnedRate) : null;

    const iconUrl = trophyMeta.trophyIconUrl || null;
    const trophyIdStr = trophyMeta.trophyId.toString();
    
    // Check if we already have a valid proxied URL
    const existingProxied = existingProxiedMap.get(trophyIdStr);
    let proxiedIconUrl = null;
    
    if (isValidProxiedUrl(existingProxied, trophyIdStr)) {
      // Reuse existing valid proxied URL (skip upload)
      proxiedIconUrl = existingProxied;
      console.log(`[PSN SYNC] ✓ Reusing valid proxied URL for trophy ${trophyIdStr}`);
    } else if (iconUrl) {
      // Upload new icon (NULL or invalid existing URL)
      proxiedIconUrl = await uploadExternalIcon(iconUrl, trophyIdStr, gameId, 'psn', supabase);
    }

    const statusFields = computeStatusXpFields({ rarityPercent, isPlatinum });

    const trophyGroupId = trophyMeta.trophyGroupId ?? 'default';
    const isDlc = trophyGroupId !== 'default';
    const dlcName = trophyGroupMap?.get(trophyGroupId) || (isDlc ? `DLC ${trophyGroupId}` : null);

    rows.push({
      platform_id: platformId,
      platform_game_id: gameId,
      platform_achievement_id: trophyMeta.trophyId.toString(),
      name: trophyMeta.trophyName || '',
      description: trophyMeta.trophyDetail || null,
      icon_url: iconUrl,
      proxied_icon_url: proxiedIconUrl || null,
      rarity_global: rarityPercent,
      score_value: 0,
      base_status_xp: statusFields.base_status_xp,
      include_in_score: statusFields.include_in_score,
      is_platinum: statusFields.is_platinum,
      metadata: {
        psn_trophy_type: trophyMeta.trophyType,
        platform_version: platformVersion,
        trophy_group_id: trophyGroupId,
        is_dlc: isDlc,
        dlc_name: dlcName,
        steam_hidden: false,
        xbox_is_secret: false,
      },
    });
  }

  const { error } = await supabase
    .from('achievements')
    .upsert(rows, { onConflict: 'platform_id,platform_game_id,platform_achievement_id' });

  if (error) throw new Error(`Failed to upsert achievements batch: ${error.message}`);
}

async function upsertUserAchievementsBatch({ userId, platformId, gameId, userTrophies }) {
  const earnedRows = [];
  let mostRecent = null;

  for (const ut of userTrophies) {
    if (!ut?.earned) continue;

    const earnedAtIso = ut.earnedDateTime || null;
    
    // Skip achievements without earned_at timestamp - DB requires non-null
    if (!earnedAtIso) {
      console.warn(`⚠️  Skipping trophy ${ut.trophyId} for game ${gameId} - missing earnedDateTime`);
      continue;
    }
    
    if (earnedAtIso) {
      const d = new Date(earnedAtIso);
      if (!mostRecent || d > mostRecent) mostRecent = d;
    }

    earnedRows.push({
      user_id: userId,
      platform_id: platformId,
      platform_game_id: gameId,
      platform_achievement_id: ut.trophyId.toString(),
      earned_at: earnedAtIso,
    });
  }

  if (earnedRows.length) {
    const BATCH_SIZE = 500;
    for (let i = 0; i < earnedRows.length; i += BATCH_SIZE) {
      const chunk = earnedRows.slice(i, i + BATCH_SIZE);
      const { error } = await supabase
        .from('user_achievements')
        .upsert(chunk, { onConflict: 'user_id,platform_id,platform_game_id,platform_achievement_id' });

      if (error) throw new Error(`Failed to upsert user_achievements batch: ${error.message}`);
    }
  }

  return { earnedCount: earnedRows.length, mostRecentEarnedAt: mostRecent?.toISOString() ?? null };
}

async function upsertUserProgress({
  userId,
  platformId,
  gameId,
  title,
  totalTrophies,
  earnedTrophies,
  mostRecentEarnedAt,
}) {
  const completionPercentage = Number(title.progress ?? 0);
  const earnedSummary = title.earnedTrophies || {};

  const payload = {
    user_id: userId,
    platform_id: platformId,
    platform_game_id: gameId,
    completion_percentage: completionPercentage,
    total_achievements: totalTrophies,
    achievements_earned: earnedTrophies,
    last_played_at: title.lastUpdatedDateTime || null,
    last_achievement_earned_at: mostRecentEarnedAt,
    metadata: {
      bronze_trophies: earnedSummary.bronze || 0,
      silver_trophies: earnedSummary.silver || 0,
      gold_trophies: earnedSummary.gold || 0,
      platinum_trophies: earnedSummary.platinum || 0,
      has_platinum: (earnedSummary.platinum || 0) > 0,
      last_rarity_sync: new Date().toISOString(),
      sync_failed: false,
      sync_error: null,
      last_sync_attempt: new Date().toISOString(),
      np_service_name: title.npServiceName || null,
    },
  };

  const { error } = await supabase
    .from('user_progress')
    .upsert(payload, { onConflict: 'user_id,platform_id,platform_game_id' });

  if (error) throw new Error(`Failed to upsert user_progress: ${error.message}`);
}

export async function syncPSNAchievements(
  userId,
  accountId,
  accessToken,
  refreshToken,
  syncLogId,
  options = {}
) {
  console.log(`Starting PSN sync for user ${userId}`);

  try {
    try {
      await initIGDBValidator();
      console.log('✅ IGDB validator initialized');
    } catch (err) {
      console.warn('⚠️ IGDB init failed, continuing without it:', err?.message || err);
    }

    // Validate profile exists
    const { data: profileValidation, error: profileError } = await supabase
      .from('profiles')
      .select('id')
      .eq('id', userId)
      .maybeSingle();

    if (profileError) throw new Error(`Profile lookup failed: ${profileError.message}`);
    if (!profileValidation) throw new Error(`Profile not found for user ${userId}`);

    // Create pre-sync snapshot for activity feed
    console.log('📸 Creating pre-sync snapshot for activity feed...');
    const preSnapshot = await createPreSyncSnapshot(userId);
    if (!preSnapshot) {
      console.warn('⚠️ Failed to create pre-sync snapshot, activity feed disabled for this sync');
    }

    const psnModule = await import('psn-api');
    const psnApi = psnModule.default ?? psnModule;
    const {
      getUserTitles,
      getTitleTrophies,
      getTitleTrophyGroups,
      getUserTrophiesEarnedForTitle,
      exchangeRefreshTokenForAuthTokens,
    } = psnApi;

    // Refresh tokens immediately (PSN tokens can expire mid-run)
    console.log('Refreshing PSN access token...');
    const authTokens = await exchangeRefreshTokenForAuthTokens(refreshToken);
    let currentAccessToken = authTokens.accessToken;
    let currentRefreshToken = authTokens.refreshToken;

    // Save tokens + start status
    await updateSyncStatus(userId, {
      psn_access_token: currentAccessToken,
      psn_refresh_token: currentRefreshToken,
      psn_sync_status: 'syncing',
      psn_sync_progress: 0,
      psn_sync_error: null,
    });

    await supabase.from('psn_sync_logs').update({ status: 'syncing' }).eq('id', syncLogId);

    // Note: PSN avatars are uploaded during account linking flow, not during sync
    // The token used for trophy sync doesn't have permissions for profile endpoints (403)
    
    // Fetch ALL titles w/ pagination
    console.log('Fetching ALL PSN titles with pagination...');
    let allTitles = [];
    let offset = 0;
    const limit = 800;

    while (true) {
      const res = await getUserTitles({ accessToken: currentAccessToken }, accountId, { limit, offset });
      const batch = res?.trophyTitles ?? [];
      if (!batch.length) break;
      allTitles = allTitles.concat(batch);
      offset += batch.length;
      if (batch.length < limit) break;
    }

    console.log(`Total PSN titles fetched: ${allTitles.length}`);

    if (!allTitles.length) {
      await updateSyncStatus(userId, {
        psn_sync_status: 'success',
        psn_sync_progress: 100,
        last_psn_sync_at: new Date().toISOString(),
      });
      await supabase
        .from('psn_sync_logs')
        .update({
          status: 'completed',
          completed_at: new Date().toISOString(),
          games_processed: 0,
          trophies_synced: 0,
        })
        .eq('id', syncLogId);
      return;
    }

    // Keep your behavior: only titles with progress > 0
    // If you want *all* titles, change this to: const gamesToProcess = allTitles;
    let gamesToProcess = allTitles.filter((t) => Number(t.progress || 0) > 0);

    // DEDUP FIX: Remove duplicate cross-gen games (same npCommunicationId on multiple platforms)
    // PSN API returns cross-gen games multiple times - keep only the newest platform version
    const seenNpIds = new Map();
    const dedupedGames = [];
    for (const title of gamesToProcess) {
      const npId = title.npCommunicationId;
      if (seenNpIds.has(npId)) {
        const existing = seenNpIds.get(npId);
        const { platformId: existingPlatformId } = mapPsnPlatformToPlatformId(existing.trophyTitlePlatform);
        const { platformId: newPlatformId } = mapPsnPlatformToPlatformId(title.trophyTitlePlatform);
        
        // Keep the newer platform (lower platform_id = newer: PS5=1, PS4=2, PS3=5)
        if (newPlatformId < existingPlatformId) {
          console.log(`🔄 DEDUP: Upgrading ${title.trophyTitleName} from platform_id=${existingPlatformId} to ${newPlatformId}`);
          seenNpIds.set(npId, title);
          dedupedGames[dedupedGames.indexOf(existing)] = title;
        } else {
          console.log(`⏭️  DEDUP: Skipping duplicate ${title.trophyTitleName} (already have platform_id=${existingPlatformId})`);
        }
      } else {
        seenNpIds.set(npId, title);
        dedupedGames.push(title);
      }
    }
    gamesToProcess = dedupedGames;

    console.log(`Found ${gamesToProcess.length} games after deduplication (removed ${allTitles.filter((t) => Number(t.progress || 0) > 0).length - gamesToProcess.length} duplicates)`);
    logMemory('After filtering gamesToProcess');

    const BATCH_SIZE = parseInt(options.batchSize, 10) || ENV_BATCH_SIZE;
    const MAX_CONCURRENT = parseInt(options.maxConcurrent, 10) || ENV_MAX_CONCURRENT;
    const forceFullSync = process.env.FORCE_FULL_SYNC === 'true';
    console.log(`Using BATCH_SIZE=${BATCH_SIZE}, MAX_CONCURRENT=${MAX_CONCURRENT}`);

    let processedGames = 0;
    let totalEarnedTrophiesUpserted = 0;

    const { data: existingUserGames } = await supabase
      .from('user_progress')
      .select('platform_id, platform_game_id, achievements_earned, total_achievements, completion_percentage, metadata')
      .eq('user_id', userId)
      .in('platform_id', [1, 2, 5, 9]);

    const userGamesMap = new Map();
    for (const ug of existingUserGames || []) {
      userGamesMap.set(`${ug.platform_id}_${ug.platform_game_id}`, ug);
    }

    const processTitle = async (title) => {
      // Token refresh every 100 games
      if (processedGames > 0 && processedGames % 100 === 0) {
        console.log('🔄 Refreshing PSN token after 100 games...');
        const t = await exchangeRefreshTokenForAuthTokens(currentRefreshToken);
        currentAccessToken = t.accessToken;
        currentRefreshToken = t.refreshToken;
        await supabase
          .from('profiles')
          .update({ psn_access_token: t.accessToken, psn_refresh_token: t.refreshToken })
          .eq('id', userId);
      }

      const { platformId, platformVersion } = mapPsnPlatformToPlatformId(title.trophyTitlePlatform);

      // Guard: Validate platform mapping cannot be overridden
      validatePlatformMapping(
        title.trophyTitlePlatform,
        platformId,
        title.trophyTitleName,
        title.npCommunicationId
      );

      console.log('[PSN_TITLE_SNAPSHOT]', JSON.stringify({
        trophyTitleName: title.trophyTitleName,
        trophyTitlePlatform: title.trophyTitlePlatform,
        npCommunicationId: title.npCommunicationId,
        npServiceName: title.npServiceName,
        progress: title.progress,
        definedTrophies: title.definedTrophies,
        earnedTrophies: title.earnedTrophies,
        lastUpdatedDateTime: title.lastUpdatedDateTime,
      }));

      // Upsert game (platform-specific composite key)
      const game = await upsertGame({ platformId, platformVersion, title });

      const existingUserGame = userGamesMap.get(`${platformId}_${game.platform_game_id}`);
      const totalFromTitle = Object.values(title.definedTrophies || {}).reduce((sum, v) => sum + Number(v || 0), 0);
      const earnedFromTitle = Object.values(title.earnedTrophies || {}).reduce((sum, v) => sum + Number(v || 0), 0);
      const countsChanged = existingUserGame &&
        (existingUserGame.total_achievements !== totalFromTitle || existingUserGame.achievements_earned !== earnedFromTitle);

      // Check if rarity is stale (>30 days old)
      let needRarityRefresh = false;
      if (existingUserGame?.metadata?.last_rarity_sync) {
        const lastRaritySync = new Date(existingUserGame.metadata.last_rarity_sync);
        const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
        needRarityRefresh = lastRaritySync < thirtyDaysAgo;
      } else if (existingUserGame) {
        needRarityRefresh = true;
      }

      let missingAchievements = false;
      if (existingUserGame && earnedFromTitle > 0) {
        const { count: uaCount } = await supabase
          .from('user_achievements')
          .select('user_id', { count: 'exact', head: true })
          .eq('user_id', userId)
          .eq('platform_id', platformId)
          .eq('platform_game_id', game.platform_game_id);

        missingAchievements = (uaCount || 0) < earnedFromTitle;
        if (missingAchievements) {
          console.log(`🔄 MISSING ACHIEVEMENTS: ${title.trophyTitleName} shows ${earnedFromTitle} earned but ${uaCount || 0} synced - reprocessing`);
        }
      }

      let hasAchievementDefs = true;
      if (existingUserGame) {
        const { count: achCount } = await supabase
          .from('achievements')
          .select('platform_achievement_id', { count: 'exact', head: true })
          .eq('platform_id', platformId)
          .eq('platform_game_id', game.platform_game_id);
        hasAchievementDefs = (achCount || 0) > 0;
      }

      const needsProcessing = forceFullSync || !existingUserGame || countsChanged || missingAchievements || !hasAchievementDefs || needRarityRefresh;
      
      // Only check for missing/invalid proxied URLs if we would otherwise skip (avoid timeout from processing too many games)
      if (!needsProcessing && existingUserGame) {
        const { count: missingProxyCount } = await supabase
          .from('achievements')
          .select('platform_achievement_id', { count: 'exact', head: true })
          .eq('platform_id', platformId)
          .eq('platform_game_id', game.platform_game_id)
          .is('proxied_icon_url', null)
          .not('icon_url', 'is', null);
        
        // Also check for invalid proxied URLs (numbered folders or timestamped files)
        const { data: invalidProxiedAchs } = await supabase
          .from('achievements')
          .select('platform_achievement_id, proxied_icon_url')
          .eq('platform_id', platformId)
          .eq('platform_game_id', game.platform_game_id)
          .not('proxied_icon_url', 'is', null);
        
        let invalidCount = 0;
        if (invalidProxiedAchs) {
          for (const ach of invalidProxiedAchs) {
            const url = ach.proxied_icon_url;
            // Invalid if: numbered folder OR timestamped OR missing gameId prefix
            const validPattern = new RegExp(`/avatars/achievement-icons/psn/${game.platform_game_id}_${ach.platform_achievement_id}\\.(png|jpg|jpeg|gif|webp)$`, 'i');
            if (/\/avatars\/achievement-icons\/\d+\//.test(url) || 
                /_\d{13}\.(png|jpg|jpeg|gif|webp)$/i.test(url) ||
                !validPattern.test(url)) {
              invalidCount++;
            }
          }
        }
        
        const totalIssues = (missingProxyCount || 0) + invalidCount;
        if (totalIssues > 0) {
          console.log(`🔄 INVALID PROXIED URLS: ${title.trophyTitleName} has ${missingProxyCount || 0} missing + ${invalidCount} invalid proxied icons - reprocessing`);
          // Continue to process this game
        } else {
          console.log(`⏭️  Skip ${title.trophyTitleName} - no changes`);
          processedGames++;
          const pct = Math.floor((processedGames / gamesToProcess.length) * 100);
          await supabase.from('profiles').update({ psn_sync_progress: pct }).eq('id', userId);
          return;
        }
      }
      
      if (forceFullSync) {
        console.log(`🔄 FULL SYNC MODE: ${title.trophyTitleName} - reprocessing to fix data`);
      }

      // Fetch trophy groups first (for DLC names)
      let trophyGroupMap = new Map();
      trophyGroupMap.set('default', 'Base Game');
      
      if (title.hasTrophyGroups) {
        try {
          const groupsData = await getTitleTrophyGroups(
            { accessToken: currentAccessToken },
            title.npCommunicationId,
            { npServiceName: title.npServiceName }
          );
          
          const groups = groupsData?.trophyGroups ?? [];
          for (const group of groups) {
            trophyGroupMap.set(group.trophyGroupId, group.trophyGroupName);
          }
          console.log(`📦 Found ${groups.length} trophy groups for ${title.trophyTitleName}`);
        } catch (err) {
          console.warn(`⚠️  Failed to fetch trophy groups for ${title.trophyTitleName}: ${err.message}`);
        }
      }

      // Fetch trophy metadata + user earned data (source of truth)
      const trophyMetadata = await getTitleTrophies(
        { accessToken: currentAccessToken },
        title.npCommunicationId,
        'all',
        { npServiceName: title.npServiceName }
      );

      const userTrophyData = await getUserTrophiesEarnedForTitle(
        { accessToken: currentAccessToken },
        accountId,
        title.npCommunicationId,
        'all',
        { npServiceName: title.npServiceName }
      );

      const trophies = trophyMetadata?.trophies ?? [];
      const userTrophies = userTrophyData?.trophies ?? [];

      if (!trophies.length) {
        throw new Error(`No trophies returned for ${title.trophyTitleName} (${title.npCommunicationId})`);
      }

      // Map user trophies by trophyId for rarity lookup
      const userTrophyMap = new Map();
      for (const ut of userTrophies) userTrophyMap.set(ut.trophyId, ut);

      // Batch upsert achievements (DB write is ONE call)
      await upsertAchievementsBatch({
        platformId,
        platformVersion,
        gameId: game.platform_game_id,
        trophies,
        userTrophyMap,
        trophyGroupMap,
      });

      // CLEANUP: Delete older platform_id versions of this game (same platform_game_id)
      // This handles existing duplicates that were synced before deduplication was added
      const { error: deleteError } = await supabase
        .from('user_achievements')
        .delete()
        .eq('user_id', userId)
        .eq('platform_game_id', game.platform_game_id)
        .neq('platform_id', platformId);  // Delete all platform_ids EXCEPT the current one
      
      if (deleteError) {
        console.warn(`⚠️  Failed to cleanup duplicate platform_ids for ${title.trophyTitleName}: ${deleteError.message}`);
      } else {
        // Also cleanup user_progress
        await supabase
          .from('user_progress')
          .delete()
          .eq('user_id', userId)
          .eq('platform_game_id', game.platform_game_id)
          .neq('platform_id', platformId);
      }

      // Batch upsert user_achievements for earned only (DB write is ONE call)
      const { earnedCount, mostRecentEarnedAt } = await upsertUserAchievementsBatch({
        userId,
        platformId,
        gameId: game.platform_game_id,
        userTrophies,
      });

      totalEarnedTrophiesUpserted += earnedCount;

      // Totals come from actual trophy list, earned from actual earned rows
      const totalTrophies = trophies.length;
      const earnedTrophies = earnedCount;

      // Update user_progress AFTER trophies are verified present
      await upsertUserProgress({
        userId,
        platformId,
        gameId: game.platform_game_id,
        title,
        totalTrophies,
        earnedTrophies,
        mostRecentEarnedAt,
      });

      processedGames++;
      const pct = Math.floor((processedGames / gamesToProcess.length) * 100);
      await supabase.from('profiles').update({ psn_sync_progress: pct }).eq('id', userId);

      console.log(`✅ Processed ${processedGames}/${gamesToProcess.length} (${pct}%)`);
      await sleep(10);
    };

    for (let i = 0; i < gamesToProcess.length; i += BATCH_SIZE) {
      if (await isCancelled(userId)) {
        console.log('PSN sync cancelled by user');
        await updateSyncStatus(userId, { psn_sync_status: 'stopped', psn_sync_progress: 0 });

        await supabase
          .from('psn_sync_logs')
          .update({ status: 'cancelled', error: 'Cancelled by user' })
          .eq('id', syncLogId);

        return;
      }

      const batch = gamesToProcess.slice(i, i + BATCH_SIZE);
      logMemory(`Before PSN batch ${i / BATCH_SIZE + 1}`);

      if (MAX_CONCURRENT <= 1) {
        for (const title of batch) await processTitle(title);
      } else {
        for (let k = 0; k < batch.length; k += MAX_CONCURRENT) {
          const chunk = batch.slice(k, k + MAX_CONCURRENT);
          await Promise.all(chunk.map((t) => processTitle(t)));
        }
      }

      logMemory(`After PSN batch ${i / BATCH_SIZE + 1}`);
    }

    // Refresh StatusXP leaderboard for this user only
    console.log('Running refresh_statusxp_leaderboard_for_user...');
    try {
      await supabase.rpc('refresh_statusxp_leaderboard_for_user', { p_user_id: userId });
      console.log('✅ refresh_statusxp_leaderboard_for_user complete');
    } catch (e) {
      console.warn('⚠️ refresh_statusxp_leaderboard_for_user failed:', e.message);
    }

    await updateSyncStatus(userId, {
      psn_sync_status: 'success',
      psn_sync_progress: 100,
      last_psn_sync_at: new Date().toISOString(),
      psn_sync_error: null,
    });

    // Generate activity feed stories if snapshot exists
    if (preSnapshot) {
      console.log('📊 Detecting changes and generating activity feed stories...');
      try {
        await detectChangesAndGenerateStories(userId, preSnapshot);
        console.log('✅ Activity feed stories generated');
      } catch (feedError) {
        console.error('⚠️ Activity feed generation failed (non-fatal):', feedError);
      }
    }

    await supabase
      .from('psn_sync_logs')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        games_processed: processedGames,
        trophies_synced: totalEarnedTrophiesUpserted,
      })
      .eq('id', syncLogId);

    console.log(`✅ PSN sync completed: games=${processedGames}, earned trophies upserted=${totalEarnedTrophiesUpserted}`);
  } catch (error) {
    console.error('🚨 PSN sync failed:', error);

    await updateSyncStatus(userId, {
      psn_sync_status: 'error',
      psn_sync_progress: 0,
      psn_sync_error: String(error.message || error).substring(0, 500),
    });

    await supabase
      .from('psn_sync_logs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: String(error.message || error).substring(0, 500),
      })
      .eq('id', syncLogId);
  }
}
