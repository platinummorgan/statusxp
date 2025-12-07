import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const ENV_BATCH_SIZE = parseInt(process.env.BATCH_SIZE || '5', 10);
const ENV_MAX_CONCURRENT = parseInt(process.env.MAX_CONCURRENT || '1', 10);

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
        const updateData = { steam_display_name: displayName };
        if (avatarUrl) {
          updateData.steam_avatar_url = avatarUrl;
        }
        const saveResult = await supabase
          .from('profiles')
          .update(updateData)
          .eq('id', userId);
        console.log('[STEAM NAME SAVE] Save result:', saveResult.error || 'OK');
      } else {
        console.log('[STEAM NAME FETCH] ❌ FAILED - Player not found in response');
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

    // Load ALL user_games ONCE for fast lookup
    console.log('Loading all user_games for comparison...');
    const { data: allUserGames } = await supabase
      .from('user_games')
      .select('game_title_id, platform_id, earned_trophies, total_trophies, completion_percent, last_rarity_sync')
      .eq('user_id', userId);
    
    const userGamesMap = new Map();
    (allUserGames || []).forEach(ug => {
      userGamesMap.set(`${ug.game_title_id}_${ug.platform_id}`, ug);
    });
    console.log(`Loaded ${userGamesMap.size} existing user_games into memory`);

    let processedGames = 0;
    let totalAchievements = 0;

    const BATCH_SIZE = parseInt(options.batchSize, 10) || ENV_BATCH_SIZE;
    const MAX_CONCURRENT = parseInt(options.maxConcurrent, 10) || ENV_MAX_CONCURRENT;
    console.log(`Using BATCH_SIZE=${BATCH_SIZE}, MAX_CONCURRENT=${MAX_CONCURRENT}`);

    // Process in batches to limit memory use
    for (let i = 0; i < ownedGames.length; i += BATCH_SIZE) {
      const batch = ownedGames.slice(i, i + BATCH_SIZE);
      logMemory(`Before processing Steam batch ${i / BATCH_SIZE + 1}`);
      if (MAX_CONCURRENT <= 1) {
        for (const game of batch) {
        try {
        console.log(`Processing Steam app ${game.appid} - ${game.name}`);
        
        // Get app details to check if it's DLC
        const appDetailsResponse = await fetch(
          `https://store.steampowered.com/api/appdetails?appids=${game.appid}`
        );
        const appDetailsData = await appDetailsResponse.json();
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
        const schemaData = await schemaResponse.json();
        const achievements = schemaData.game?.availableGameStats?.achievements || [];

        if (achievements.length === 0) continue;

        // Get player achievements
        const playerAchievementsResponse = await fetch(
          `https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v1/?key=${apiKey}&steamid=${steamId}&appid=${game.appid}`
        );
        console.log('Player achievements fetch status:', playerAchievementsResponse.status);
        const playerAchievementsData = await playerAchievementsResponse.json();
        const playerAchievements = playerAchievementsData.playerstats?.achievements || [];

        // Get or create Steam platform
        const { data: platform } = await supabase
          .from('platforms')
          .select('id')
          .eq('code', 'Steam')
          .single();
        
        if (!platform) {
          console.error('Steam platform not found in database!');
          continue;
        }
        
        // Search for existing game_title by name (case-insensitive)
        let gameTitle = null;
        const { data: existingGame } = await supabase
          .from('game_titles')
          .select('id, name, cover_url')
          .ilike('name', game.name)
          .limit(1)
          .maybeSingle();
        
        if (existingGame) {
          // Update cover if we don't have one
          if (!existingGame.cover_url) {
            await supabase
              .from('game_titles')
              .update({ 
                cover_url: `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`
              })
              .eq('id', existingGame.id);
          }
          gameTitle = existingGame;
        } else {
          // Create new game_title
          const { data: newGame } = await supabase
            .from('game_titles')
            .insert({
              name: game.name,
              cover_url: `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`,
              metadata: {
                steam_app_id: game.appid,
                is_dlc: isDLC,
                dlc_name: dlcName,
                base_game_app_id: baseGameAppId,
              },
            })
            .select()
            .single();
          gameTitle = newGame;
        }

        if (!gameTitle) continue;

        // Get unlocked count from API data (already fetched earlier)
        const unlockedCount = playerAchievements.filter(a => a.achieved === 1).length;
        
        // Simple lookup - is this game new or changed?
        const existingUserGame = userGamesMap.get(`${gameTitle.id}_${platform.id}`);
        const isNewGame = !existingUserGame;
        const earnedChanged = existingUserGame && existingUserGame.earned_trophies !== unlockedCount;
        
        // Check if rarity is stale (>30 days old)
        let needRarityRefresh = false;
        if (!isNewGame && !earnedChanged && existingUserGame) {
          const lastRaritySync = existingUserGame.last_rarity_sync ? new Date(existingUserGame.last_rarity_sync) : null;
          const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
          needRarityRefresh = !lastRaritySync || lastRaritySync < thirtyDaysAgo;
        }
        
        const needAchievements = isNewGame || earnedChanged || needRarityRefresh;

        if (!needAchievements) {
          console.log(`⏭️  Skip ${game.name} - no changes`);
          processedGames++;
          const progressPercent = Math.floor((processedGames / ownedGames.length) * 100);
          await supabase.from('profiles').update({ steam_sync_progress: progressPercent }).eq('id', userId);
          continue;
        }
        
        if (needRarityRefresh) {
          console.log(`🔄 RARITY REFRESH: ${game.name} (>30 days since last rarity sync)`);
        } else {
          console.log(`🔄 ${isNewGame ? 'NEW' : 'UPDATED'}: ${game.name} (unlocked: ${unlockedCount})`);
        }

        const progress = achievements.length > 0 ? (unlockedCount / achievements.length) * 100 : 0;

        // Fetch global achievement percentages for rarity data
        const globalStats = {};
        try {
          const globalResponse = await fetch(
            `https://api.steampowered.com/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/?gameid=${game.appid}&format=json`
          );

          if (globalResponse.ok) {
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

        // Upsert user_games
        await supabase
          .from('user_games')
          .upsert({
            user_id: userId,
            game_title_id: gameTitle.id,
            platform_id: platform.id,
            total_trophies: achievements.length,
            earned_trophies: unlockedCount,
            completion_percent: progress,
            last_rarity_sync: new Date().toISOString(),
          }, {
            onConflict: 'user_id,game_title_id,platform_id',
          });

        // Process achievements
        for (let j = 0; j < achievements.length; j++) {
          const achievement = achievements[j];
          const playerAchievement = playerAchievements.find(a => a.apiname === achievement.name);
          const rarityPercent = globalStats[achievement.name] || 0;

          // Upsert achievement with rarity data
          const { data: achievementRecord, error: achError } = await supabase
            .from('achievements')
            .upsert({
              game_title_id: gameTitle.id,
              platform: 'steam',
              platform_achievement_id: achievement.name,
              name: achievement.displayName || achievement.name,
              description: achievement.description || '',
              icon_url: achievement.icon || '',
              steam_hidden: achievement.hidden === 1,
              rarity_global: rarityPercent,
              is_dlc: isDLC,
              dlc_name: dlcName,
            }, {
              onConflict: 'game_title_id,platform,platform_achievement_id',
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
            await supabase
              .from('user_achievements')
              .upsert({
                user_id: userId,
                achievement_id: achievementRecord.id,
                earned_at: new Date(playerAchievement.unlocktime * 1000).toISOString(),
              }, {
                onConflict: 'user_id,achievement_id',
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
          // Continue with next game
        }
      }
      }
      logMemory(`After processing Steam batch ${i / BATCH_SIZE + 1}`);
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
