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
async function shouldFetchTrophies({
  userId,
  gameTitleId,
  platformId,
  apiProgress,
  apiTotalTrophies,
  apiEarnedTrophies,
}) {
  const [userGameRes, achStatsRes] = await Promise.all([
    supabase
      .from('user_games')
      .select('completion_percent,total_trophies,earned_trophies')
      .eq('user_id', userId)
      .eq('game_title_id', gameTitleId)
      .eq('platform_id', platformId)
      .maybeSingle(),
    supabase
      .from('achievements')
      .select('total=count(*),with_rarity=count(rarity_global),with_band=count(rarity_band),with_multiplier=count(rarity_multiplier),with_base_xp=count(base_status_xp),with_platinum=count(is_platinum),with_include_score=count(include_in_score)')
      .eq('game_title_id', gameTitleId)
      .eq('platform', 'psn')
      .single(),
  ]);

  const existingUserGame = userGameRes.data || null;
  const achStats = achStatsRes.data || { total: 0, with_rarity: 0, with_band: 0, with_multiplier: 0, with_base_xp: 0, with_platinum: 0, with_include_score: 0 };

  const localTotal = Number(achStats.total ?? 0);
  const withRarity = Number(achStats.with_rarity ?? 0);
  const withBand = Number(achStats.with_band ?? 0);
  const withMultiplier = Number(achStats.with_multiplier ?? 0);
  const withBaseXp = Number(achStats.with_base_xp ?? 0);
  const withPlatinum = Number(achStats.with_platinum ?? 0);
  const withIncludeScore = Number(achStats.with_include_score ?? 0);

  const gameLevelChanged =
    !existingUserGame ||
    Number(existingUserGame.completion_percent ?? 0) !== Number(apiProgress ?? 0) ||
    Number(existingUserGame.total_trophies ?? 0) !== Number(apiTotalTrophies ?? 0) ||
    Number(existingUserGame.earned_trophies ?? 0) !== Number(apiEarnedTrophies ?? 0);

  const achievementsIncomplete =
    localTotal < apiTotalTrophies || // not enough rows
    withRarity < localTotal || // some trophies missing rarity
    withBand < localTotal || // some trophies missing rarity band
    withMultiplier < localTotal || // some trophies missing multiplier
    withBaseXp < localTotal || // some trophies missing base XP
    withPlatinum < localTotal || // some trophies missing platinum flag
    withIncludeScore < localTotal; // some trophies missing include_in_score

  // Fetch if game state changed OR achievements look incomplete
  const shouldFetch = gameLevelChanged || achievementsIncomplete;

  if (!shouldFetch) {
    console.log(
      `⏭️  Skipping trophy fetch for game_title_id=${gameTitleId} (no game-level changes, ${localTotal} trophies, ${localTotal - withRarity} missing rarity, ${localTotal - withBand} missing bands)`
    );
  }

  return shouldFetch;
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

  const psnModule = await import('psn-api');
  const psnApi = psnModule.default ?? psnModule;
  const { getUserTitles, getTitleTrophies, exchangeRefreshTokenForAuthTokens } =
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
    const titles = await getUserTitles(
      { accessToken: currentAccessToken },
      accountId
    );
    console.log(
      'PSN titles fetched, trophyTitles length:',
      titles?.trophyTitles?.length ?? 0
    );

    if (!titles?.trophyTitles || titles.trophyTitles.length === 0) {
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

    const gamesWithTrophies = titles.trophyTitles.filter(
      (title) =>
        title.earnedTrophies.bronze > 0 ||
        title.earnedTrophies.silver > 0 ||
        title.earnedTrophies.gold > 0 ||
        title.earnedTrophies.platinum > 0
    );

    console.log(`Found ${gamesWithTrophies.length} games with trophies`);
    logMemory('After filtering gamesWithTrophies');

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
          const { data: existingGame } = await supabase
            .from('game_titles')
            .select('id, cover_url')
            .ilike('name', title.trophyTitleName)
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
                name: title.trophyTitleName,
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

          // Decide if we actually need the heavy trophy call
          const needTrophies = await shouldFetchTrophies({
            userId,
            gameTitleId: gameTitle.id,
            platformId: platform.id,
            apiProgress,
            apiTotalTrophies,
            apiEarnedTrophies,
          });

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

          console.log(`🔄 Fetching trophy details for ${title.trophyTitleName}`);
          const trophyData = await getTitleTrophies(
            { accessToken: currentAccessToken },
            title.npCommunicationId,
            'all',
            { npServiceName: title.npServiceName }
          );
          console.log(
            'Fetched trophies count:',
            trophyData?.trophies?.length ?? 0
          );

          if (!trophyData?.trophies || trophyData.trophies.length === 0) {
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

          for (const trophy of trophyData.trophies) {
            const isDLC =
              trophy.trophyGroupId && trophy.trophyGroupId !== 'default';
            const dlcName = isDLC ? `DLC Group ${trophy.trophyGroupId}` : null;
            const rarityPercent = trophy.trophyEarnedRate
              ? parseFloat(trophy.trophyEarnedRate)
              : null;

            if (rarityPercent !== null && rarityPercent > 0) {
              console.log(
                `[PSN RARITY] ${trophy.trophyName}: ${rarityPercent}%`
              );
            }

            const { data: achievementRecord } = await supabase
              .from('achievements')
              .upsert(
                {
                  game_title_id: gameTitle.id,
                  platform: 'psn',
                  platform_achievement_id: trophy.trophyId.toString(),
                  name: trophy.trophyName,
                  description: trophy.trophyDetail,
                  icon_url: trophy.trophyIconUrl,
                  psn_trophy_type: trophy.trophyType,
                  rarity_global: rarityPercent,
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

            if (trophy.earned) {
              await supabase
                .from('user_achievements')
                .upsert(
                  {
                    user_id: userId,
                    achievement_id: achievementRecord.id,
                    earned_at: trophy.earnedDateTime,
                  },
                  {
                    onConflict: 'user_id,achievement_id',
                  }
                );

              totalTrophies++;
            }
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
