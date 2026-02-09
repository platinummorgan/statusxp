import { createClient } from '@supabase/supabase-js';
import { uploadExternalIcon, uploadGameCover } from './icon-proxy-utils.js';
import { createPreSyncSnapshot, detectChangesAndGenerateStories } from './activity-feed-snapshots.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const ENV_BATCH_SIZE = parseInt(process.env.BATCH_SIZE || '5', 10);
const ENV_MAX_CONCURRENT = parseInt(process.env.MAX_CONCURRENT || '1', 10);
const STEAM_PROGRESS_UPDATE_EVERY = Math.max(1, parseInt(process.env.STEAM_PROGRESS_UPDATE_EVERY || '10', 10));
const STEAM_GAME_YIELD_MS = Math.max(0, parseInt(process.env.STEAM_GAME_YIELD_MS || '0', 10));
const STEAM_LOOKUP_CHUNK_SIZE = Math.max(25, parseInt(process.env.STEAM_LOOKUP_CHUNK_SIZE || '200', 10));
const STEAM_ENABLE_CONSISTENCY_CHECKS = process.env.STEAM_ENABLE_CONSISTENCY_CHECKS !== 'false';
const STEAM_ALWAYS_FETCH_APPDETAILS = process.env.STEAM_ALWAYS_FETCH_APPDETAILS === 'true';
const STEAM_DEBUG_SYNC = process.env.STEAM_DEBUG_SYNC === 'true';

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
    console.log(label, `rss=${Math.round(m.rss/1024/1024)}MB`, `heapUsed=${Math.round(m.heapUsed/1024/1024)}MB`, `heapTotal=${Math.round(m.heapTotal/1024/1024)}MB`, `external=${Math.round(m.external/1024/1024)}MB`);
  } catch (e) {
    console.log('logMemory error', e.message);
  }
}

export async function syncSteamAchievements(userId, steamId, apiKey, syncLogId, options = {}) {
  console.log(`Starting Steam sync for user ${userId}`);
  const syncStartedAtMs = Date.now();
  
  try {
    // Fetch Steam persona name
    console.log('[STEAM NAME FETCH] Starting fetch for steamId:', steamId);
    let displayName = null;
    try {
      const playerUrl = `https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v2/?key=${apiKey}&steamids=${steamId}`;
      console.log('[STEAM NAME FETCH] URL:', playerUrl.replace(apiKey, 'API_KEY_HIDDEN'));
      const playerResponse = await fetch(playerUrl);
      
      console.log('[STEAM NAME FETCH] Response status:', playerResponse.status);
      const contentType = playerResponse.headers.get('content-type');
      if (!playerResponse.ok || !contentType?.includes('application/json')) {
        console.log(`[STEAM NAME FETCH] ❌ Invalid response (status ${playerResponse.status}, type ${contentType})`);
        throw new Error(`Steam API returned non-JSON response`);
      }
      const playerData = await playerResponse.json();
      console.log('[STEAM NAME FETCH] Response data:', JSON.stringify(playerData));
      const player = playerData.response?.players?.[0];
      if (player) {
        displayName = player.personaname;
        const avatarUrl = player.avatarfull || player.avatarmedium || player.avatar;
        console.log('[STEAM NAME FETCH] ✅ SUCCESS - Fetched Steam display name:', displayName);
        console.log('[STEAM NAME FETCH] ✅ SUCCESS - Fetched Steam avatar URL:', avatarUrl);
        
        // Save display name and avatar to profile
        console.log('[STEAM NAME SAVE] Saving to database for user:', userId);
        
        // Get current profile to check display_name and preferred_display_platform
        const { data: currentProfile } = await supabase
          .from('profiles')
          .select('display_name, preferred_display_platform')
          .eq('id', userId)
          .single();
        
        const updateData = { steam_display_name: displayName };
        
        // If display_name is missing or should use Steam name, update it
        if (!currentProfile?.display_name || currentProfile.preferred_display_platform === 'steam') {
          updateData.display_name = displayName;
          console.log('[STEAM NAME SAVE] Updating display_name to:', displayName);
        }
        
        if (avatarUrl) {
          console.log('[STEAM NAME SAVE] Proxying Steam avatar through Supabase Storage...');
          const proxiedUrl = await uploadExternalAvatar(avatarUrl, userId, 'steam');
          if (proxiedUrl) {
            updateData.steam_avatar_url = proxiedUrl;
            console.log('[STEAM NAME SAVE] Successfully proxied Steam avatar:', proxiedUrl);
          } else {
            console.warn('[STEAM NAME SAVE] Failed to proxy avatar, using external URL');
            updateData.steam_avatar_url = avatarUrl;
          }
        }
        const saveResult = await supabase
          .from('profiles')
          .update(updateData)
          .eq('id', userId);
        console.log('[STEAM NAME SAVE] Save result:', saveResult.error || 'OK');
      } else {
        console.log('[STEAM NAME FETCH] ❌ FAILED - Player not found in response');
        console.log('[STEAM NAME FETCH] ❌ Invalid Steam ID:', steamId);
        throw new Error(`Invalid Steam ID - player not found: ${steamId}`);
      }
    } catch (e) {
      console.error('[STEAM NAME FETCH] ❌ EXCEPTION:', e.message, e.stack);
    }

    // Set initial status
    await supabase
      .from('profiles')
      .update({ steam_sync_status: 'syncing', steam_sync_progress: 0 })
      .eq('id', userId);

    await supabase
      .from('steam_sync_logs')
      .update({ status: 'syncing' })
      .eq('id', syncLogId);

    // Create pre-sync snapshot for activity feed
    console.log('📸 Creating pre-sync snapshot for activity feed...');
    const preSnapshot = await createPreSyncSnapshot(userId);
    if (!preSnapshot) {
      console.warn('⚠️ Failed to create pre-sync snapshot, activity feed disabled for this sync');
    }

    // Fetch owned games
    const gamesResponse = await fetch(
      `https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=${apiKey}&steamid=${steamId}&include_appinfo=1&include_played_free_games=1`
    );
    const gamesContentType = gamesResponse.headers.get('content-type');
    if (!gamesResponse.ok || !gamesContentType?.includes('application/json')) {
      throw new Error(`Steam API returned non-JSON response for owned games (status ${gamesResponse.status})`);
    }
    const gamesData = await gamesResponse.json();
    const ownedGames = gamesData.response?.games || [];

    console.log(`Found ${ownedGames.length} owned games`);
    
    if (ownedGames.length === 0) {
      console.log('No Steam games found - marking sync as success with 0 games');
      await supabase
        .from('profiles')
        .update({
          steam_sync_status: 'success',
          steam_sync_progress: 100,
          last_steam_sync_at: new Date().toISOString(),
        })
        .eq('id', userId);

      await supabase
        .from('steam_sync_logs')
        .update({
          status: 'completed',
          completed_at: new Date().toISOString(),
          games_processed: 0,
          achievements_synced: 0,
        })
        .eq('id', syncLogId);
      return;
    }

    logMemory('After fetching ownedGames');

    // V2 Schema: Steam has single platform_id
    // Steam=4
    console.log('Steam sync: Steam=4');
    let platformId = 4; // Steam platform ID

    // Load existing user_progress to enable cheap diff
    const { data: existingUserGames } = await supabase
      .from('user_progress')
      .select('platform_game_id, platform_id, total_achievements, achievements_earned, metadata, synced_at')
      .eq('user_id', userId)
      .eq('platform_id', platformId);
    
    const userGamesMap = new Map();
    for (const ug of existingUserGames || []) {
      userGamesMap.set(`${ug.platform_game_id}_${ug.platform_id}`, ug);
    }
    console.log(`Loaded ${userGamesMap.size} existing user_progress records into memory`);

    // Preload existing Steam game rows to avoid per-game lookup queries.
    const ownedGameIds = [...new Set((ownedGames || []).map((g) => String(g.appid)).filter(Boolean))];
    const existingSteamGamesMap = new Map();
    for (let idx = 0; idx < ownedGameIds.length; idx += STEAM_LOOKUP_CHUNK_SIZE) {
      const idsChunk = ownedGameIds.slice(idx, idx + STEAM_LOOKUP_CHUNK_SIZE);
      const { data: existingGameChunk, error: existingGameChunkError } = await supabase
        .from('games')
        .select('platform_game_id, cover_url, metadata')
        .eq('platform_id', platformId)
        .in('platform_game_id', idsChunk);
      if (existingGameChunkError) {
        console.error(`⚠️ Failed preloading Steam games chunk (${idx}/${ownedGameIds.length}):`, existingGameChunkError.message);
        continue;
      }
      for (const row of existingGameChunk || []) {
        existingSteamGamesMap.set(String(row.platform_game_id), row);
      }
    }
    console.log(`Preloaded ${existingSteamGamesMap.size} existing Steam games for this sync run`);

    let processedGames = 0;
    let totalAchievements = 0;
    let titlesSeen = 0;
    let titlesSkipped = 0;
    let titlesFailed = 0;
    let titlesFullyProcessed = 0;

    const BATCH_SIZE = parseInt(options.batchSize, 10) || ENV_BATCH_SIZE;
    const configuredMaxConcurrent = parseInt(options.maxConcurrent, 10) || ENV_MAX_CONCURRENT;
    const MAX_CONCURRENT = configuredMaxConcurrent > 1 ? 1 : configuredMaxConcurrent;
    const shouldPersistProgress = (processed, total) =>
      processed === total || processed % STEAM_PROGRESS_UPDATE_EVERY === 0;
    if (configuredMaxConcurrent > 1) {
      console.warn(
        `STEAM MAX_CONCURRENT=${configuredMaxConcurrent} requested, but only sequential path is validated. ` +
        `Forcing MAX_CONCURRENT=1 to protect sync reliability.`
      );
    }
    console.log(`Using BATCH_SIZE=${BATCH_SIZE}, MAX_CONCURRENT=${MAX_CONCURRENT}`);

    // Process in batches to limit memory use
    for (let i = 0; i < ownedGames.length; i += BATCH_SIZE) {
      // Check if sync was cancelled
      const { data: profileCheck } = await supabase
        .from('profiles')
        .select('steam_sync_status')
        .eq('id', userId)
        .maybeSingle();
      
      if (profileCheck?.steam_sync_status === 'cancelling') {
        console.log('Steam sync cancelled by user');
        await supabase
          .from('profiles')
          .update({ 
            steam_sync_status: 'stopped',
            steam_sync_progress: 0 
          })
          .eq('id', userId);
        
        await supabase
          .from('steam_sync_logs')
          .update({
            status: 'cancelled',
            completed_at: new Date().toISOString(),
          })
          .eq('id', syncLogId);
        
        return;
      }
      
      const batch = ownedGames.slice(i, i + BATCH_SIZE);
      logMemory(`Before processing Steam batch ${i / BATCH_SIZE + 1}`);
      if (MAX_CONCURRENT <= 1) {
        for (let batchIndex = 0; batchIndex < batch.length; batchIndex++) {
          const game = batch[batchIndex];
          titlesSeen++;
          
          // Check for cancellation every 5 games within batch
          if (batchIndex > 0 && batchIndex % 5 === 0) {
            const { data: cancelCheck } = await supabase
              .from('profiles')
              .select('steam_sync_status')
              .eq('id', userId)
              .maybeSingle();
            
            if (cancelCheck?.steam_sync_status === 'cancelling') {
              console.log('Steam sync cancelled by user (mid-batch)');
              await supabase
                .from('profiles')
                .update({ 
                  steam_sync_status: 'stopped',
                  steam_sync_progress: 0 
                })
                .eq('id', userId);
              
              await supabase
                .from('steam_sync_logs')
                .update({
                  status: 'cancelled',
                  completed_at: new Date().toISOString(),
                })
                .eq('id', syncLogId);
              
              return;
            }
          }
          
          // Declare variables outside try block so catch can access them
          let gameTitle = null;
          
          try {
            console.log(`Processing Steam app ${game.appid} - ${game.name}`);

            // FAST SKIP: If playtime hasn't changed recently, avoid full processing
            const existingUserGameQuick = userGamesMap.get(`${game.appid}_${platformId}`);
            const fastSkipHours = parseInt(process.env.STEAM_FAST_SKIP_HOURS || '24', 10);
            const fastSkipCutoff = new Date(Date.now() - fastSkipHours * 60 * 60 * 1000);
            const lastSyncAttemptRaw = existingUserGameQuick?.metadata?.last_sync_attempt || existingUserGameQuick?.synced_at;
            const lastSyncAttempt = lastSyncAttemptRaw ? new Date(lastSyncAttemptRaw) : null;
            const storedPlaytime = existingUserGameQuick?.metadata?.steam_playtime_forever;
            const storedLastPlayed = existingUserGameQuick?.metadata?.steam_rtime_last_played;
            const playtimeUnchanged =
              existingUserGameQuick &&
              Number(storedPlaytime) === Number(game.playtime_forever) &&
              Number(storedLastPlayed) === Number(game.rtime_last_played);

            if (playtimeUnchanged && lastSyncAttempt && lastSyncAttempt > fastSkipCutoff) {
              console.log(`⏭️  Fast skip ${game.name} - playtime unchanged (last sync ${fastSkipHours}h)`);
              titlesSkipped++;
              await supabase
                .from('user_progress')
                .update({
                  metadata: {
                    ...(existingUserGameQuick?.metadata || {}),
                    steam_playtime_forever: game.playtime_forever,
                    steam_rtime_last_played: game.rtime_last_played,
                    last_sync_attempt: new Date().toISOString(),
                  },
                })
                .eq('user_id', userId)
                .eq('platform_id', platformId)
                .eq('platform_game_id', game.appid);

              processedGames++;
              const progressPercent = Math.floor((processedGames / ownedGames.length) * 100);
              if (shouldPersistProgress(processedGames, ownedGames.length)) {
                await supabase.from('profiles').update({ steam_sync_progress: progressPercent }).eq('id', userId);
              }
              continue;
            }
            
            const existingMetadata = existingUserGameQuick?.metadata || {};
            let isDLC = typeof existingMetadata.is_dlc === 'boolean' ? existingMetadata.is_dlc : false;
            let dlcName = existingMetadata.dlc_name || null;
            let baseGameAppId = existingMetadata.base_game_app_id || null;

            const shouldFetchAppDetails = STEAM_ALWAYS_FETCH_APPDETAILS || typeof existingMetadata.is_dlc !== 'boolean';
            if (shouldFetchAppDetails) {
              // Only fetch appdetails when DLC metadata is unknown (or forced via env).
              let appDetailsData;
              try {
                const appDetailsResponse = await fetch(
                  `https://store.steampowered.com/api/appdetails?appids=${game.appid}`
                );
                const appDetailsContentType = appDetailsResponse.headers.get('content-type');
                if (appDetailsResponse.ok && appDetailsContentType?.includes('application/json')) {
                  appDetailsData = await appDetailsResponse.json();
                }
              } catch (e) {
                console.log(`⚠️ App details fetch failed for ${game.appid}: ${e.message}`);
              }

              const appDetails = appDetailsData?.[game.appid]?.data;
              if (appDetails) {
                isDLC = appDetails?.type === 'dlc';
                dlcName = isDLC ? appDetails?.name : null;
                baseGameAppId = isDLC ? appDetails?.fullgame?.appid : null;
              }
            }
            
            console.log(`App ${game.appid} is ${isDLC ? 'DLC' : 'base game'}${isDLC ? ` (base: ${baseGameAppId})` : ''}`);
            
            // Get game schema (achievements list)
            const schemaResponse = await fetch(
              `https://api.steampowered.com/ISteamUserStats/GetSchemaForGame/v2/?key=${apiKey}&appid=${game.appid}`
            );
            console.log('Schema fetch status:', schemaResponse.status);
            
            // Check if response is JSON before parsing
            const contentType = schemaResponse.headers.get('content-type');
            if (!schemaResponse.ok || !contentType?.includes('application/json')) {
              console.log(`⚠️ Schema fetch failed for ${game.appid} (status ${schemaResponse.status}, type ${contentType}) - skipping game`);
              titlesSkipped++;
              continue;
            }
            
            const schemaData = await schemaResponse.json();
            const achievements = schemaData.game?.availableGameStats?.achievements || [];

            if (achievements.length === 0) {
              console.log(`⏭️  Skip ${game.name} - no achievements in Steam schema`);
              titlesSkipped++;
              continue;
            }

            // Get player achievements to check counts
            const playerAchievementsResponse = await fetch(
              `https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v1/?key=${apiKey}&steamid=${steamId}&appid=${game.appid}`
            );
            console.log('Player achievements fetch status:', playerAchievementsResponse.status);
            
            // Check player achievements response is JSON
            const playerContentType = playerAchievementsResponse.headers.get('content-type');
            if (!playerAchievementsResponse.ok || !playerContentType?.includes('application/json')) {
              console.log(`⚠️ Player achievements fetch failed for ${game.appid} (status ${playerAchievementsResponse.status}) - skipping game`);
              titlesSkipped++;
              continue;
            }
            
            const playerAchievementsData = await playerAchievementsResponse.json();
            const playerAchievements = playerAchievementsData.playerstats?.achievements || [];

            // Quick count check
            const unlockedCount = playerAchievements.filter(a => a.achieved === 1).length;
            const totalCount = achievements.length;

            console.log(`📱 Platform: Steam (ID ${platformId})`);
            
            // Find or create game using Steam appid
            const trimmedName = game.name.trim();
            const existingGame = existingSteamGamesMap.get(game.appid.toString()) || null;
            
            if (existingGame) {
              // Update cover if we don't have one
              if (!existingGame.cover_url) {
                const externalCoverUrl = `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`;
                const proxiedCoverUrl = await uploadGameCover(externalCoverUrl, platformId, game.appid.toString(), supabase);
                
                const { error: updateError } = await supabase
                  .from('games')
                  .update({ 
                    cover_url: proxiedCoverUrl || externalCoverUrl
                  })
                  .eq('platform_id', platformId)
                  .eq('platform_game_id', existingGame.platform_game_id);
                
                if (updateError) {
                  console.error('❌ Failed to update game cover:', game.name, 'Error:', updateError);
                }
              }
              gameTitle = existingGame;
            } else {
              // Upsert game with V2 composite key (race-condition safe)
              const externalCoverUrl = `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`;
              const proxiedCoverUrl = await uploadGameCover(externalCoverUrl, platformId, game.appid.toString(), supabase);
              
              const gamePayload = {
                platform_id: platformId,
                platform_game_id: game.appid.toString(),
                name: trimmedName,
                metadata: {
                  steam_app_id: game.appid,
                  platform_version: 'Steam',
                  is_dlc: isDLC,
                  dlc_name: dlcName,
                  base_game_app_id: baseGameAppId,
                },
              };
              
              // Only set cover_url if we have a new value
              const newCoverUrl = proxiedCoverUrl || externalCoverUrl;
              if (newCoverUrl) {
                gamePayload.cover_url = newCoverUrl;
              }
              
              const { data: newGame, error: insertError } = await supabase
                .from('games')
                .upsert(gamePayload, {
                  onConflict: 'platform_id,platform_game_id'
                })
                .select()
                .single();
              
              if (insertError) {
                console.error('❌ Failed to upsert game:', game.name, 'Error:', insertError);
                titlesFailed++;
                continue;
              }
              gameTitle = newGame;
              existingSteamGamesMap.set(String(newGame.platform_game_id), newGame);
            }

            if (!gameTitle) {
              titlesFailed++;
              continue;
            }

            // Cheap diff: Check if game data changed
            const existingUserGame = userGamesMap.get(`${gameTitle.platform_game_id}_${platformId}`);
            const isNewGame = !existingUserGame;
            const countsChanged = existingUserGame && 
              (existingUserGame.total_achievements !== totalCount || existingUserGame.achievements_earned !== unlockedCount);
            const syncFailed = existingUserGame && existingUserGame.metadata?.sync_failed === true;

            // BUG FIX: Force processing if user_progress is missing even when achievements exist
            // This handles the case where a previous sync wrote user_achievements but crashed before writing user_progress
            let missingUserProgress = false;
            if (STEAM_ENABLE_CONSISTENCY_CHECKS && !isNewGame) {
              // Double-check DB to ensure user_progress actually exists (handles edge case where map is stale)
              const { data: dbUserProgress } = await supabase
                .from('user_progress')
                .select('platform_game_id')
                .eq('user_id', userId)
                .eq('platform_id', platformId)
                .eq('platform_game_id', game.appid.toString())
                .maybeSingle();
              
              if (!dbUserProgress) {
                missingUserProgress = true;
                console.log(`🔧 MISSING USER_PROGRESS FIX: ${game.name} has achievements but no progress record - forcing creation`);
              }
            }

            if (STEAM_DEBUG_SYNC && isNewGame) {
              try {
                const { data: debugUserGame } = await supabase
                  .from('user_progress')
                  .select('platform_game_id, platform_id')
                  .eq('user_id', userId)
                  .eq('platform_id', platformId)
                  .eq('platform_game_id', game.appid.toString())
                  .maybeSingle();

                console.log(
                  `🔎 NEW GAME DEBUG ${game.name}: ` +
                  `mapKey=${gameTitle.platform_game_id}_${platformId} ` +
                  `mapHas=${userGamesMap.has(`${gameTitle.platform_game_id}_${platformId}`)} ` +
                  `dbFound=${debugUserGame != null}`
                );
              } catch (debugErr) {
                console.log(`🔎 NEW GAME DEBUG failed for ${game.name}: ${debugErr.message}`);
              }
            }
            
            // Check if rarity is stale (>30 days old)
            let needRarityRefresh = false;
            if (!isNewGame && !countsChanged && !syncFailed && existingUserGame) {
              const lastRaritySyncRaw = existingUserGame.metadata?.last_rarity_sync
                || existingUserGame.metadata?.last_sync_attempt
                || existingUserGame.synced_at;
              const lastRaritySync = lastRaritySyncRaw ? new Date(lastRaritySyncRaw) : null;
              const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
              needRarityRefresh = !lastRaritySync || lastRaritySync < thirtyDaysAgo;
            }
            
            // BUG FIX: Check if achievements were never processed (achievements_earned > 0 but no user_achievements)
            // This happens if initial sync failed to process achievements
            let missingAchievements = false;
            let hasAchievementDefs = true;
            if (STEAM_ENABLE_CONSISTENCY_CHECKS && !isNewGame && !countsChanged && !needRarityRefresh) {
              const { count: achCount } = await supabase
                .from('achievements')
                .select('platform_achievement_id', { count: 'exact', head: true })
                .eq('platform_id', platformId)
                .eq('platform_game_id', gameTitle.platform_game_id);
              hasAchievementDefs = (achCount || 0) > 0;
            }
            if (STEAM_ENABLE_CONSISTENCY_CHECKS && !isNewGame && !countsChanged && !needRarityRefresh && existingUserGame?.achievements_earned > 0) {
              const { count: uaCount } = await supabase
                .from('user_achievements')
                .select('user_id', { count: 'exact', head: true })
                .eq('user_id', userId)
                .eq('platform_id', platformId)
                .eq('platform_game_id', gameTitle.platform_game_id);
              
              missingAchievements = (uaCount || 0) < unlockedCount;
              if (missingAchievements) {
                console.log(`🔄 MISSING ACHIEVEMENTS: ${game.name} shows ${unlockedCount} earned but ${uaCount || 0} synced - reprocessing`);
              }
            }
            
            const forceFullSync = process.env.FORCE_FULL_SYNC === 'true';
            const needsProcessing = forceFullSync || isNewGame || countsChanged || needRarityRefresh || missingAchievements || syncFailed || !hasAchievementDefs || missingUserProgress;
            const reasonFlags = {
              forceFullSync,
              isNewGame,
              countsChanged,
              needRarityRefresh,
              missingAchievements,
              syncFailed,
              missingAchievementDefs: !hasAchievementDefs,
              missingUserProgress,
            };
            if (syncFailed) {
              console.log(`🔄 RETRY FAILED SYNC: ${game.name} (previous sync failed)`);
            }
            if (!needsProcessing) {
              console.log(`⏭️  Skip ${game.name} - no changes`);
              titlesSkipped++;
              processedGames++;
              const progressPercent = Math.floor((processedGames / ownedGames.length) * 100);
              if (shouldPersistProgress(processedGames, ownedGames.length)) {
                await supabase.from('profiles').update({ steam_sync_progress: progressPercent }).eq('id', userId);
              }
              continue;
            }
            console.log(`🧭 Processing reasons for ${game.name}:`, JSON.stringify(reasonFlags));
            if (forceFullSync) {
              console.log(`🔄 FULL SYNC MODE: ${game.name} - reprocessing to fix data`);
            }
            
            if (needRarityRefresh) {
              console.log(`🔄 RARITY REFRESH: ${game.name} (>30 days since last rarity sync)`);
            }

            // Calculate progress
            const progress = achievements.length > 0 ? (unlockedCount / achievements.length) * 100 : 0;

            // Fetch global achievement percentages for rarity data
            const globalStats = {};
            try {
              const globalResponse = await fetch(
                `https://api.steampowered.com/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/?gameid=${game.appid}&format=json`
              );

              const globalContentType = globalResponse.headers.get('content-type');
              if (globalResponse.ok && globalContentType?.includes('application/json')) {
                const globalData = await globalResponse.json();
                if (globalData.achievementpercentages?.achievements) {
                  for (const ach of globalData.achievementpercentages.achievements) {
                    globalStats[ach.name] = ach.percent;
                  }
                }
              }
            } catch (error) {
              console.log(`Could not fetch global stats for ${game.name}:`, error.message);
            }

            // Find most recent achievement unlock time
            let lastTrophyEarnedAt = null;
            for (const achievement of achievements) {
              const playerAch = playerAchievements.find(a => a.apiname === achievement.name);
              if (playerAch && playerAch.achieved === 1 && playerAch.unlocktime > 0) {
                const unlockDate = new Date(playerAch.unlocktime * 1000);
                if (!lastTrophyEarnedAt || unlockDate > lastTrophyEarnedAt) {
                  lastTrophyEarnedAt = unlockDate;
                }
              }
            }

            // Upsert user_progress with V2 fields
            await supabase
              .from('user_progress')
              .upsert({
                user_id: userId,
                platform_id: platformId,
                platform_game_id: gameTitle.platform_game_id,
                total_achievements: achievements.length,
                achievements_earned: unlockedCount,
                completion_percentage: progress,
                last_trophy_earned_at: lastTrophyEarnedAt ? lastTrophyEarnedAt.toISOString() : null,
                metadata: {
                  platform_version: 'Steam',
                  is_dlc: isDLC,
                  dlc_name: dlcName,
                  base_game_app_id: baseGameAppId,
                  steam_playtime_forever: game.playtime_forever,
                  steam_rtime_last_played: game.rtime_last_played,
                  last_rarity_sync: new Date().toISOString(),
                  sync_failed: false,
                  sync_error: null,
                  last_sync_attempt: new Date().toISOString(),
                },
              }, {
                onConflict: 'user_id,platform_id,platform_game_id',
              });

            // Fetch existing achievements to check for valid proxied URLs
            const achievementNames = achievements.map(a => a.name);
            const { data: existingAchievements } = await supabase
              .from('achievements')
              .select('platform_achievement_id, proxied_icon_url')
              .eq('platform_id', platformId)
              .eq('platform_game_id', gameTitle.platform_game_id)
              .in('platform_achievement_id', achievementNames);

            const existingProxiedMap = new Map();
            if (existingAchievements) {
              for (const ach of existingAchievements) {
                existingProxiedMap.set(ach.platform_achievement_id, ach.proxied_icon_url);
              }
            }

            // Helper to check if proxied URL is valid (not NULL, not numbered folder, not timestamped, matches achievement ID)
            const isValidProxiedUrl = (url, achievementId) => {
              if (!url) return false;
              if (!url.includes('/avatars/achievement-icons/steam/')) return false;
              if (/\/avatars\/achievement-icons\/\d+\//.test(url)) return false;
              if (/_\d{13}\.(png|jpg|jpeg|gif|webp)$/i.test(url)) return false;
              // Filename must match gameId_achievementId pattern: ends with /{gameId}_{achievementId}.ext
              const filePattern = new RegExp(`/${gameTitle.platform_game_id}_${achievementId}\\.(png|jpg|jpeg|gif|webp)$`, 'i');
              if (!filePattern.test(url)) return false;
              return true;
            };

            // Batch strategy: keep per-achievement transforms/icon proxying, then write in chunks.
            // This avoids N+1 DB writes for achievements and user_achievements.
            const playerAchievementsMap = new Map();
            for (const pa of playerAchievements) {
              playerAchievementsMap.set(pa.apiname, pa);
            }

            const achievementsToUpsert = [];
            const unlockedUserAchievementCandidates = [];
            const successfulAchievementIds = new Set();
            const UPSERT_CHUNK_SIZE = parseInt(process.env.STEAM_UPSERT_CHUNK_SIZE || '200', 10);

            // Build payloads
            for (let j = 0; j < achievements.length; j++) {
              const achievement = achievements[j];
              const playerAchievement = playerAchievementsMap.get(achievement.name);
              const rarityPercent = globalStats[achievement.name] || null;

              // Calculate base_status_xp using EXPONENTIAL CURVE (floor=0.5, cap=12, p=3)
              let baseStatusXP = 0.5; // Default for NULL rarity (treat as common)
              
              if (rarityPercent !== null && !Number.isNaN(Number(rarityPercent))) {
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

              // Proxy the icon if available (check existing first)
              const iconUrl = achievement.icon || '';
              const existingProxied = existingProxiedMap.get(achievement.name);
              let proxiedIconUrl = null;
              
              if (isValidProxiedUrl(existingProxied, achievement.name)) {
                proxiedIconUrl = existingProxied;
                console.log(`[STEAM SYNC] ✓ Reusing valid proxied URL for ${achievement.name}`);
              } else if (iconUrl) {
                proxiedIconUrl = await uploadExternalIcon(iconUrl, achievement.name, gameTitle.platform_game_id, 'steam', supabase);
              }

              // Upsert achievement with V2 composite keys and StatusXP
              const achievementData = {
                platform_id: platformId,
                platform_game_id: gameTitle.platform_game_id,
                platform_achievement_id: achievement.name,
                name: achievement.displayName || achievement.name,
                description: achievement.description || '',
                icon_url: iconUrl,
                rarity_global: rarityPercent,
                base_status_xp: baseStatusXP,
                is_platinum: false, // Steam doesn't have platinums
                include_in_score: true, // All Steam achievements count
                metadata: {
                  platform_version: 'Steam',
                  steam_hidden: achievement.hidden === 1,
                  is_dlc: isDLC,
                  dlc_name: dlcName,
                },
              };

              // Only include proxied_icon_url if upload succeeded
              if (proxiedIconUrl) {
                achievementData.proxied_icon_url = proxiedIconUrl;
              }

              achievementsToUpsert.push(achievementData);

              // Upsert user_achievement if unlocked
              if (playerAchievement && playerAchievement.achieved === 1) {
                // SAFETY: Steam should never have platinums
                if (achievementData.is_platinum) {
                  console.log(`⚠️ [VALIDATION BLOCKED] Steam achievement marked as platinum: ${achievement.name}`);
                  continue;
                }

                unlockedUserAchievementCandidates.push({
                  user_id: userId,
                  platform_id: platformId,
                  platform_game_id: gameTitle.platform_game_id,
                  platform_achievement_id: achievement.name,
                  earned_at: new Date(playerAchievement.unlocktime * 1000).toISOString(),
                });
              }
            }

            // Batch upsert achievements first to satisfy FK for user_achievements.
            for (let i = 0; i < achievementsToUpsert.length; i += UPSERT_CHUNK_SIZE) {
              const chunk = achievementsToUpsert.slice(i, i + UPSERT_CHUNK_SIZE);
              const chunkIds = chunk.map((row) => row.platform_achievement_id);

              const { error: chunkError } = await supabase
                .from('achievements')
                .upsert(chunk, {
                  onConflict: 'platform_id,platform_game_id,platform_achievement_id',
                });

              if (!chunkError) {
                for (const id of chunkIds) successfulAchievementIds.add(id);
                continue;
              }

              // Fallback keeps sync resilient if one bad row breaks a batch.
              console.warn(`⚠️ Steam achievements batch upsert failed, retrying row-by-row: ${chunkError.message}`);
              for (const row of chunk) {
                const { error: rowError } = await supabase
                  .from('achievements')
                  .upsert(row, {
                    onConflict: 'platform_id,platform_game_id,platform_achievement_id',
                  });
                if (rowError) {
                  console.error(`❌ Failed to upsert achievement ${row.platform_achievement_id}:`, rowError.message);
                  continue;
                }
                successfulAchievementIds.add(row.platform_achievement_id);
              }
            }

            // Only write unlocked rows whose achievement definition is present.
            const userAchievementsToUpsert = unlockedUserAchievementCandidates.filter((row) =>
              successfulAchievementIds.has(row.platform_achievement_id)
            );

            for (let i = 0; i < userAchievementsToUpsert.length; i += UPSERT_CHUNK_SIZE) {
              const chunk = userAchievementsToUpsert.slice(i, i + UPSERT_CHUNK_SIZE);
              const { error: chunkError } = await supabase
                .from('user_achievements')
                .upsert(chunk, {
                  onConflict: 'user_id,platform_id,platform_game_id,platform_achievement_id',
                });

              if (!chunkError) {
                totalAchievements += chunk.length;
                continue;
              }

              // Fallback to identify exact failing row while still processing the rest.
              console.warn(`⚠️ Steam user_achievements batch upsert failed, retrying row-by-row: ${chunkError.message}`);
              for (const row of chunk) {
                const { error: rowError } = await supabase
                  .from('user_achievements')
                  .upsert(row, {
                    onConflict: 'user_id,platform_id,platform_game_id,platform_achievement_id',
                  });
                if (rowError) {
                  throw new Error(`Failed to upsert user_achievement ${row.platform_achievement_id}: ${rowError.message}`);
                }
                totalAchievements++;
              }
            }

            titlesFullyProcessed++;
            processedGames++;
            const progressPercent = Math.floor((processedGames / ownedGames.length) * 100);
            
            // Update progress
            if (shouldPersistProgress(processedGames, ownedGames.length)) {
              await supabase
                .from('profiles')
                .update({ steam_sync_progress: progressPercent })
                .eq('id', userId);
            }

            console.log(`Processed ${processedGames}/${ownedGames.length} games (${progressPercent}%)`);
            // brief pause to yield to the event loop and let memory settle
            if (STEAM_GAME_YIELD_MS > 0) {
              await new Promise((r) => setTimeout(r, STEAM_GAME_YIELD_MS));
            }
            
          } catch (error) {
            console.error(`Error processing game ${game.name}:`, error);
            titlesFailed++;
            
            // Mark sync as failed for this game
            try {
              const { data: existingGame } = await supabase
                .from('user_progress')
                .select('metadata')
                .eq('user_id', userId)
                .eq('platform_id', platformId)
                .eq('platform_game_id', gameTitle?.platform_game_id)
                .single();
              
              await supabase
                .from('user_progress')
                .update({
                  metadata: {
                    ...(existingGame?.metadata || {}),
                    sync_failed: true,
                    sync_error: (error.message || String(error)).substring(0, 255),
                    last_sync_attempt: new Date().toISOString(),
                  }
                })
                .eq('user_id', userId)
                .eq('platform_id', platformId)
                .eq('platform_game_id', gameTitle?.platform_game_id);
            } catch (updateErr) {
              console.error('Failed to mark sync_failed:', updateErr);
            }
            
            // Continue with next game
          }
        }
      }
      
      logMemory(`After processing Steam batch ${i / BATCH_SIZE + 1}`);
    }

    const titlesUnaccounted = Math.max(0, titlesSeen - (titlesSkipped + titlesFailed + titlesFullyProcessed));
    console.log(
      `Steam sync summary: seen=${titlesSeen}, fully_processed=${titlesFullyProcessed}, ` +
      `skipped=${titlesSkipped}, failed=${titlesFailed}, unaccounted=${titlesUnaccounted}, ` +
      `progress_counter=${processedGames}/${ownedGames.length}`
    );

    // Refresh StatusXP leaderboard for this user only
    console.log('Running refresh_statusxp_leaderboard_for_user...');
    try {
      await supabase.rpc('refresh_statusxp_leaderboard_for_user', { p_user_id: userId });
      console.log('✅ refresh_statusxp_leaderboard_for_user complete');
    } catch (calcError) {
      console.error('⚠️ refresh_statusxp_leaderboard_for_user failed:', calcError);
    }

    // Mark as completed
    await supabase
      .from('profiles')
      .update({
        steam_sync_status: 'success',
        steam_sync_progress: 100,
        last_steam_sync_at: new Date().toISOString(),
      })
      .eq('id', userId);

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
      .from('steam_sync_logs')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        games_processed: processedGames,
        achievements_synced: totalAchievements,
        error_message: null,
      })
      .eq('id', syncLogId);

    console.log(`Steam sync completed: ${processedGames} games, ${totalAchievements} achievements`);
    console.log(`Steam sync duration: ${Math.round((Date.now() - syncStartedAtMs) / 1000)}s`);

  } catch (error) {
    console.error('Steam sync failed:', error);
    
    await supabase
      .from('profiles')
      .update({
        steam_sync_status: 'error',
        steam_sync_error: error.message,
      })
      .eq('id', userId);

    await supabase
      .from('steam_sync_logs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: error.message,
      })
      .eq('id', syncLogId);
  }
}
