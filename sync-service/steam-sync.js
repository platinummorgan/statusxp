import { createClient } from '@supabase/supabase-js';
import { uploadExternalIcon, uploadGameCover } from './icon-proxy-utils.js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const ENV_BATCH_SIZE = parseInt(process.env.BATCH_SIZE || '5', 10);
const ENV_MAX_CONCURRENT = parseInt(process.env.MAX_CONCURRENT || '1', 10);

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
    
    // Create a unique filename: platform/userId_timestamp.ext
    const timestamp = Date.now();
    const filename = `${platform}/${userId}_${timestamp}.${extension}`;
    
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

    let processedGames = 0;
    let totalAchievements = 0;

    const BATCH_SIZE = parseInt(options.batchSize, 10) || ENV_BATCH_SIZE;
    const MAX_CONCURRENT = parseInt(options.maxConcurrent, 10) || ENV_MAX_CONCURRENT;
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
            
            // Get app details to check if it's DLC
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
            if (!appDetailsData) {
              appDetailsData = { [game.appid]: { data: { type: 'game' } } };
            }
            const appDetails = appDetailsData?.[game.appid]?.data;
            const isDLC = appDetails?.type === 'dlc';
            const dlcName = isDLC ? appDetails?.name : null;
            const baseGameAppId = isDLC ? appDetails?.fullgame?.appid : null;
            
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
              continue;
            }
            
            const schemaData = await schemaResponse.json();
            const achievements = schemaData.game?.availableGameStats?.achievements || [];

            if (achievements.length === 0) continue;

            // Get player achievements to check counts
            const playerAchievementsResponse = await fetch(
              `https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v1/?key=${apiKey}&steamid=${steamId}&appid=${game.appid}`
            );
            console.log('Player achievements fetch status:', playerAchievementsResponse.status);
            
            // Check player achievements response is JSON
            const playerContentType = playerAchievementsResponse.headers.get('content-type');
            if (!playerAchievementsResponse.ok || !playerContentType?.includes('application/json')) {
              console.log(`⚠️ Player achievements fetch failed for ${game.appid} (status ${playerAchievementsResponse.status}) - skipping game`);
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
            const { data: existingGame } = await supabase
              .from('games')
              .select('platform_game_id, cover_url, metadata')
              .eq('platform_id', platformId)
              .eq('platform_game_id', game.appid.toString())
              .maybeSingle();
            
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
              
              const { data: newGame, error: insertError } = await supabase
                .from('games')
                .upsert({
                  platform_id: platformId,
                  platform_game_id: game.appid.toString(),
                  name: trimmedName,
                  cover_url: proxiedCoverUrl || externalCoverUrl,
                  metadata: {
                    steam_app_id: game.appid,
                    platform_version: 'Steam',
                    is_dlc: isDLC,
                    dlc_name: dlcName,
                    base_game_app_id: baseGameAppId,
                  },
                }, {
                  onConflict: 'platform_id,platform_game_id'
                })
                .select()
                .single();
              
              if (insertError) {
                console.error('❌ Failed to upsert game:', game.name, 'Error:', insertError);
                continue;
              }
              gameTitle = newGame;
            }

            if (!gameTitle) continue;

            // Cheap diff: Check if game data changed
            const existingUserGame = userGamesMap.get(`${gameTitle.platform_game_id}_${platformId}`);
            const isNewGame = !existingUserGame;
            const countsChanged = existingUserGame && 
              (existingUserGame.total_achievements !== totalCount || existingUserGame.achievements_earned !== unlockedCount);
            const syncFailed = existingUserGame && existingUserGame.metadata?.sync_failed === true;
            
            // Check if rarity is stale (>30 days old)
            let needRarityRefresh = false;
            if (!isNewGame && !countsChanged && !syncFailed && existingUserGame) {
              const lastRaritySync = existingUserGame.metadata?.last_rarity_sync ? new Date(existingUserGame.metadata.last_rarity_sync) : null;
              const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
              needRarityRefresh = !lastRaritySync || lastRaritySync < thirtyDaysAgo;
            }
            
            // BUG FIX: Check if achievements were never processed (achievements_earned > 0 but no user_achievements)
            // This happens if initial sync failed to process achievements
            let missingAchievements = false;
            let hasAchievementDefs = true;
            if (!isNewGame && !countsChanged && !needRarityRefresh) {
              const { count: achCount } = await supabase
                .from('achievements')
                .select('platform_achievement_id', { count: 'exact', head: true })
                .eq('platform_id', platformId)
                .eq('platform_game_id', gameTitle.platform_game_id);
              hasAchievementDefs = (achCount || 0) > 0;
            }
            if (!isNewGame && !countsChanged && !needRarityRefresh && existingUserGame?.achievements_earned > 0) {
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
            const needsProcessing = forceFullSync || isNewGame || countsChanged || needRarityRefresh || missingAchievements || syncFailed || !hasAchievementDefs;
            if (syncFailed) {
              console.log(`🔄 RETRY FAILED SYNC: ${game.name} (previous sync failed)`);
            }
            if (!needsProcessing) {
              console.log(`⏭️  Skip ${game.name} - no changes`);
              processedGames++;
              const progressPercent = Math.floor((processedGames / ownedGames.length) * 100);
              await supabase.from('profiles').update({ steam_sync_progress: progressPercent }).eq('id', userId);
              continue;
            }
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
                  last_rarity_sync: new Date().toISOString(),
                  sync_failed: false,
                  sync_error: null,
                  last_sync_attempt: new Date().toISOString(),
                },
              }, {
                onConflict: 'user_id,platform_id,platform_game_id',
              });

            // TODO OPTIMIZATION: This achievement processing loop is N+1 (2-3 DB calls per achievement)
            // Should batch upsert achievements with unique constraint on (platform_id, platform_game_id, platform_achievement_id)
            // Then batch upsert user_achievements. Same issue as PSN/Xbox - major performance bottleneck.
            // Current: 100 achievements = 200-300 DB calls. Batch: 100 achievements = 2 DB calls.
            // Process achievements
            for (let j = 0; j < achievements.length; j++) {
              const achievement = achievements[j];
              const playerAchievement = playerAchievements.find(a => a.apiname === achievement.name);
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

              // Proxy the icon if available
              const iconUrl = achievement.icon || '';
              const proxiedIconUrl = iconUrl ? await uploadExternalIcon(iconUrl, achievement.name, 'steam', supabase) : null;

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

              // Upsert achievement with composite key
              const { data: achievementRecord, error: achError } = await supabase
                .from('achievements')
                .upsert(achievementData, {
                  onConflict: 'platform_id,platform_game_id,platform_achievement_id',
                })
                .select()
                .single();

              if (achError) {
                console.error(`❌ Failed to upsert achievement ${achievement.name}:`, achError.message);
                continue;
              }

              if (!achievementRecord) continue;

              // Upsert user_achievement if unlocked
              if (playerAchievement && playerAchievement.achieved === 1) {
                // SAFETY: Steam should never have platinums
                if (achievementRecord.is_platinum) {
                  console.log(`⚠️ [VALIDATION BLOCKED] Steam achievement marked as platinum: ${achievement.name}`);
                  continue;
                }

                await supabase
                  .from('user_achievements')
                  .upsert({
                    user_id: userId,
                    platform_id: platformId,
                    platform_game_id: gameTitle.platform_game_id,
                    platform_achievement_id: achievement.name,
                    earned_at: new Date(playerAchievement.unlocktime * 1000).toISOString(),
                  }, {
                    onConflict: 'user_id,platform_id,platform_game_id,platform_achievement_id',
                  });
                
                totalAchievements++;
              }
            }

            processedGames++;
            const progressPercent = Math.floor((processedGames / ownedGames.length) * 100);
            
            // Update progress
            await supabase
              .from('profiles')
              .update({ steam_sync_progress: progressPercent })
              .eq('id', userId);

            console.log(`Processed ${processedGames}/${ownedGames.length} games (${progressPercent}%)`);
            // brief pause to yield to the event loop and let memory settle
            await new Promise((r) => setTimeout(r, 25));
            
          } catch (error) {
            console.error(`Error processing game ${game.name}:`, error);
            
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

    await supabase
      .from('steam_sync_logs')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        games_processed: processedGames,
        achievements_synced: totalAchievements,
      })
      .eq('id', syncLogId);

    console.log(`Steam sync completed: ${processedGames} games, ${totalAchievements} achievements`);

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
