// Force redeploy after optimization fix - Dec 7, 2025
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

// Cheap diff check: DB snapshot vs API snapshot
export async function syncPSNAchievements(
  userId,
  accountId,
  accessToken,
  refreshToken,
  syncLogId,
  options = {}
) {
  console.log(`Starting PSN sync for user ${userId}`);

  const psnModule = await import('psn-api');
  const psnApi = psnModule.default ?? psnModule;
  const { getUserTitles, getTitleTrophies, getUserTrophiesEarnedForTitle, exchangeRefreshTokenForAuthTokens } =
    psnApi;

  try {
    console.log('Refreshing PSN access token...');
    const authTokens = await exchangeRefreshTokenForAuthTokens(refreshToken);
    const currentAccessToken = authTokens.accessToken;
    console.log('PSN access token refreshed successfully');

    await supabase
      .from('profiles')
      .update({
        psn_access_token: authTokens.accessToken,
        psn_refresh_token: authTokens.refreshToken,
        psn_sync_status: 'syncing',
        psn_sync_progress: 0,
      })
      .eq('id', userId);

    await supabase
      .from('psn_sync_logs')
      .update({ status: 'syncing' })
      .eq('id', syncLogId);

    console.log('Fetching PSN titles for accountId:', accountId);
    // Paginate through ALL titles (max 800 per request)
    let allTitles = [];
    let offset = 0;
    const limit = 800;
    let hasMore = true;

    console.log('Starting to fetch ALL PSN titles with pagination...');
    
    while (hasMore) {
      console.log(`Fetching titles with offset ${offset}, limit ${limit}`);
      const titles = await getUserTitles(
        { accessToken: currentAccessToken },
        accountId,
        { limit, offset }
      );
      
      const fetchedCount = titles?.trophyTitles?.length ?? 0;
      console.log(`Fetched ${fetchedCount} titles in this batch`);
      
      if (fetchedCount > 0) {
        allTitles = allTitles.concat(titles.trophyTitles);
        offset += fetchedCount;
        
        // If we got fewer titles than the limit, we've reached the end
        hasMore = fetchedCount === limit;
      } else {
        hasMore = false;
      }
    }

    console.log(`Total PSN titles fetched: ${allTitles.length}`);

    if (!allTitles || allTitles.length === 0) {
      console.log('No PSN titles found - marking sync as success with 0 games');
      await supabase
        .from('profiles')
        .update({
          psn_sync_status: 'success',
          psn_sync_progress: 100,
          last_psn_sync_at: new Date().toISOString(),
        })
        .eq('id', userId);

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

    // Sync ALL games with any trophy progress (including platinum-only games)
    const gamesWithTrophies = allTitles.filter(
      (title) => title.progress > 0
    );

    console.log(`Found ${gamesWithTrophies.length} games with progress`);
    logMemory('After filtering gamesWithTrophies');

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
    let totalTrophies = 0;

    const BATCH_SIZE = parseInt(options.batchSize, 10) || ENV_BATCH_SIZE;
    const MAX_CONCURRENT =
      parseInt(options.maxConcurrent, 10) || ENV_MAX_CONCURRENT;
    console.log(`Using BATCH_SIZE=${BATCH_SIZE}, MAX_CONCURRENT=${MAX_CONCURRENT}`);

    for (let i = 0; i < gamesWithTrophies.length; i += BATCH_SIZE) {
      const batch = gamesWithTrophies.slice(i, i + BATCH_SIZE);
      logMemory(`Before processing PSN batch ${i / BATCH_SIZE + 1}`);

      const processTitle = async (title) => {
        try {
          // Map PSN platform codes to our platform codes
          let platformCode = 'PS5';
          if (title.trophyTitlePlatform) {
            const psnPlatform = title.trophyTitlePlatform.toUpperCase();
            if (psnPlatform.includes('PS5')) platformCode = 'PS5';
            else if (psnPlatform.includes('PS4')) platformCode = 'PS4';
            else if (psnPlatform.includes('PS3')) platformCode = 'PS3';
            else if (psnPlatform.includes('VITA')) platformCode = 'PSVITA';
          }

          const { data: platform } = await supabase
            .from('platforms')
            .select('id')
            .eq('code', platformCode)
            .single();

          if (!platform) {
            console.error(
              `❌ Platform not found for code ${platformCode} (PSN: ${title.trophyTitlePlatform}), skipping game: ${title.trophyTitleName}`
            );
            return;
          }

          // Find or create game_title
          const trimmedTitle = title.trophyTitleName.trim();
          const { data: existingGame } = await supabase
            .from('game_titles')
            .select('id, cover_url')
            .ilike('name', trimmedTitle)
            .maybeSingle();

          let gameTitle;
          if (existingGame) {
            if (!existingGame.cover_url && title.trophyTitleIconUrl) {
              await supabase
                .from('game_titles')
                .update({ cover_url: title.trophyTitleIconUrl })
                .eq('id', existingGame.id);
            }
            gameTitle = existingGame;
          } else {
            const { data: newGame, error: insertError } = await supabase
              .from('game_titles')
              .insert({
                name: trimmedTitle,
                cover_url: title.trophyTitleIconUrl,
                metadata: { psn_np_communication_id: title.npCommunicationId },
              })
              .select()
              .single();

            if (insertError) {
              console.error(
                '❌ Failed to insert game_title:',
                title.trophyTitleName,
                'Error:',
                insertError
              );
              return;
            }
            gameTitle = newGame;
          }

          if (!gameTitle) return;

          // API snapshot
          const defined = title.definedTrophies || {};
          const earned = title.earnedTrophies || {};
          const apiTotalTrophies =
            (defined.bronze || 0) +
            (defined.silver || 0) +
            (defined.gold || 0) +
            (defined.platinum || 0);
          const apiEarnedTrophies =
            (earned.bronze || 0) +
            (earned.silver || 0) +
            (earned.gold || 0) +
            (earned.platinum || 0);
          const apiProgress = Number(title.progress || 0);

          // Simple lookup - is this game new or changed?
          const existingUserGame = userGamesMap.get(`${gameTitle.id}_${platform.id}`);
          const isNewGame = !existingUserGame;
          const earnedChanged = existingUserGame && existingUserGame.earned_trophies !== apiEarnedTrophies;
          
          // Check if rarity is stale (>30 days old)
          let needRarityRefresh = false;
          if (!isNewGame && !earnedChanged && existingUserGame) {
            const lastRaritySync = existingUserGame.last_rarity_sync ? new Date(existingUserGame.last_rarity_sync) : null;
            const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
            needRarityRefresh = !lastRaritySync || lastRaritySync < thirtyDaysAgo;
          }
          
          const needTrophies = isNewGame || earnedChanged || needRarityRefresh;

          if (!needTrophies) {
            console.log(`⏭️  Skip ${title.trophyTitleName} - no changes`);
            processedGames++;
            const progress = Math.floor((processedGames / gamesWithTrophies.length) * 100);
            await supabase.from('profiles').update({ psn_sync_progress: progress }).eq('id', userId);
            return;
          }
          
          if (needRarityRefresh) {
            console.log(`🔄 RARITY REFRESH: ${title.trophyTitleName} (>30 days since last rarity sync)`);
          }

          console.log(`🔄 ${isNewGame ? 'NEW' : 'UPDATED'}: ${title.trophyTitleName} (earned: ${apiEarnedTrophies})`);

          // Always upsert user_games snapshot
          await supabase
            .from('user_games')
            .upsert(
              {
                user_id: userId,
                game_title_id: gameTitle.id,
                platform_id: platform.id,
                completion_percent: apiProgress,
                total_trophies: apiTotalTrophies,
                earned_trophies: apiEarnedTrophies,
                last_rarity_sync: new Date().toISOString(),
                bronze_trophies: earned.bronze || 0,
                silver_trophies: earned.silver || 0,
                gold_trophies: earned.gold || 0,
                platinum_trophies: earned.platinum || 0,
                has_platinum: (earned.platinum || 0) > 0,
                last_played_at: title.lastUpdatedDateTime,
              },
              { onConflict: 'user_id,game_title_id,platform_id' }
            );

          if (!needTrophies) {
            // No changes + trophies complete → skip heavy call
            processedGames++;
            const progress = Math.floor(
              (processedGames / gamesWithTrophies.length) * 100
            );
            await supabase
              .from('profiles')
              .update({ psn_sync_progress: progress })
              .eq('id', userId);
            return;
          }

          console.log(`🔄 Fetching trophy details (with rarity) for ${title.trophyTitleName}`);
          
          // Fetch trophy metadata (names, descriptions, icons)
          const trophyMetadata = await getTitleTrophies(
            { accessToken: currentAccessToken },
            title.npCommunicationId,
            'all',
            { npServiceName: title.npServiceName }
          );
          
          // Fetch user trophy data (earned status + RARITY)
          const userTrophyData = await getUserTrophiesEarnedForTitle(
            { accessToken: currentAccessToken },
            accountId,
            title.npCommunicationId,
            'all',
            { npServiceName: title.npServiceName }
          );
          
          console.log(
            'Fetched trophies count:',
            trophyMetadata?.trophies?.length ?? 0,
            'with rarity data:',
            userTrophyData?.trophies?.length ?? 0
          );

          if (!trophyMetadata?.trophies || trophyMetadata.trophies.length === 0) {
            processedGames++;
            const progress = Math.floor(
              (processedGames / gamesWithTrophies.length) * 100
            );
            await supabase
              .from('profiles')
              .update({ psn_sync_progress: progress })
              .eq('id', userId);
            return;
          }

          // Create a map of user trophy data by trophyId for easy lookup
          const userTrophyMap = new Map();
          let mostRecentTrophyDate = null;
          
          for (const userTrophy of (userTrophyData?.trophies || [])) {
            userTrophyMap.set(userTrophy.trophyId, userTrophy);
            
            // Track the most recent trophy earned date
            if (userTrophy?.earned && userTrophy?.earnedDateTime) {
              const earnedDate = new Date(userTrophy.earnedDateTime);
              if (!mostRecentTrophyDate || earnedDate > mostRecentTrophyDate) {
                mostRecentTrophyDate = earnedDate;
              }
            }
          }

          for (const trophyMeta of trophyMetadata.trophies) {
            const userTrophy = userTrophyMap.get(trophyMeta.trophyId);
            
            // Debug: Log full trophy object structure for first game
            if (processedGames === 0 && trophyMetadata.trophies.indexOf(trophyMeta) === 0) {
              console.log(`[DEBUG] Trophy metadata:`, JSON.stringify(trophyMeta, null, 2));
              console.log(`[DEBUG] User trophy data:`, JSON.stringify(userTrophy, null, 2));
            }

            const isDLC =
              trophyMeta.trophyGroupId && trophyMeta.trophyGroupId !== 'default';
            const dlcName = isDLC ? `DLC Group ${trophyMeta.trophyGroupId}` : null;
            const rarityPercent = userTrophy?.trophyEarnedRate
              ? parseFloat(userTrophy.trophyEarnedRate)
              : null;

            if (rarityPercent !== null && rarityPercent > 0) {
              console.log(
                `[PSN RARITY] ${trophyMeta.trophyName}: ${rarityPercent}%`
              );
            } else {
              // Only log debug for first few trophies to avoid spam
              if (processedGames < 2 && trophyMetadata.trophies.indexOf(trophyMeta) < 5) {
                console.log(
                  `[PSN RARITY DEBUG] ${trophyMeta.trophyName}: trophyEarnedRate=${userTrophy?.trophyEarnedRate}, parsed=${rarityPercent}`
                );
              }
            }

            const { data: achievementRecord } = await supabase
              .from('achievements')
              .upsert(
                {
                  game_title_id: gameTitle.id,
                  platform: 'psn',
                  platform_achievement_id: trophyMeta.trophyId.toString(),
                  name: trophyMeta.trophyName,
                  description: trophyMeta.trophyDetail,
                  icon_url: trophyMeta.trophyIconUrl,
                  psn_trophy_type: trophyMeta.trophyType,
                  rarity_global: rarityPercent,
                  is_platinum: trophyMeta.trophyType === 'platinum',
                  include_in_score: trophyMeta.trophyType !== 'platinum',
                  is_dlc: isDLC,
                  dlc_name: dlcName,
                },
                {
                  onConflict: 'game_title_id,platform,platform_achievement_id',
                }
              )
              .select()
              .single();

            if (!achievementRecord) continue;

            if (userTrophy?.earned) {
              await supabase
                .from('user_achievements')
                .upsert(
                  {
                    user_id: userId,
                    achievement_id: achievementRecord.id,
                    earned_at: userTrophy.earnedDateTime,
                  },
                  {
                    onConflict: 'user_id,achievement_id',
                  }
                );

              totalTrophies++;
            }
          }

          // Update user_games with the most recent trophy earned date
          if (mostRecentTrophyDate) {
            await supabase
              .from('user_games')
              .update({
                last_trophy_earned_at: mostRecentTrophyDate.toISOString(),
              })
              .eq('user_id', userId)
              .eq('game_title_id', gameTitle.id)
              .eq('platform_id', platform.id);
          }

          processedGames++;
          const progress = Math.floor(
            (processedGames / gamesWithTrophies.length) * 100
          );
          await supabase
            .from('profiles')
            .update({ psn_sync_progress: progress })
            .eq('id', userId);

          console.log(
            `Processed ${processedGames}/${gamesWithTrophies.length} games (${progress}%)`
          );
          await new Promise((r) => setTimeout(r, 25));
        } catch (error) {
          console.error(`Error processing title ${title.trophyTitleName}:`, error);
        }
      };

      if (MAX_CONCURRENT <= 1) {
        // sequential
        for (const title of batch) {
          await processTitle(title);
        }
      } else {
        // chunked concurrency
        for (let k = 0; k < batch.length; k += MAX_CONCURRENT) {
          const chunk = batch.slice(k, k + MAX_CONCURRENT);
          await Promise.all(chunk.map((t) => processTitle(t)));
        }
      }

      logMemory(`After processing PSN batch ${i / BATCH_SIZE + 1}`);
    }

    // Calculate StatusXP for all achievements and games
    console.log('Calculating StatusXP values...');
    try {
      await supabase.rpc('calculate_user_achievement_statusxp');
      await supabase.rpc('calculate_user_game_statusxp');
      console.log('✅ StatusXP calculation complete');
    } catch (calcError) {
      console.error('⚠️ StatusXP calculation failed:', calcError);
    }

    await supabase
      .from('profiles')
      .update({
        psn_sync_status: 'success',
        psn_sync_progress: 100,
        last_psn_sync_at: new Date().toISOString(),
      })
      .eq('id', userId);

    await supabase
      .from('psn_sync_logs')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        games_processed: processedGames,
        trophies_synced: totalTrophies,
      })
      .eq('id', syncLogId);

    console.log(
      `PSN sync completed: ${processedGames} games, ${totalTrophies} trophies`
    );
  } catch (error) {
    console.error('PSN sync failed:', error);

    await supabase
      .from('profiles')
      .update({
        psn_sync_status: 'error',
        psn_sync_error: error.message,
      })
      .eq('id', userId);

    await supabase
      .from('psn_sync_logs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: error.message,
      })
      .eq('id', syncLogId);
  }
}
