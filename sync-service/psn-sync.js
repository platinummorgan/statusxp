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

export async function syncPSNAchievements(userId, accountId, accessToken, refreshToken, syncLogId, options = {}) {
  console.log(`Starting PSN sync for user ${userId}`);
  
  // Dynamically import PSN API at runtime to avoid startup import issues
  const psnModule = await import('psn-api');
  const psnApi = psnModule.default ?? psnModule;
  const { getUserTitles, getTitleTrophies, exchangeRefreshTokenForAuthTokens } = psnApi;
  try {
    // Refresh access token before making API calls
    console.log('Refreshing PSN access token...');
    const authTokens = await exchangeRefreshTokenForAuthTokens(refreshToken);
    const currentAccessToken = authTokens.accessToken;
    console.log('PSN access token refreshed successfully');

    // Update profile with new tokens
    await supabase
      .from('profiles')
      .update({
        psn_access_token: authTokens.accessToken,
        psn_refresh_token: authTokens.refreshToken,
        psn_sync_status: 'syncing',
        psn_sync_progress: 0
      })
      .eq('id', userId);

    await supabase
      .from('psn_sync_logs')
      .update({ status: 'syncing' })
      .eq('id', syncLogId);

    // Fetch all games
    console.log('Fetching PSN titles for accountId:', accountId);
    const titles = await getUserTitles({ accessToken: currentAccessToken }, accountId);
    console.log('PSN titles fetched, trophyTitles length:', titles?.trophyTitles?.length ?? 0);
    
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
      title => title.earnedTrophies.bronze > 0 || 
               title.earnedTrophies.silver > 0 || 
               title.earnedTrophies.gold > 0 || 
               title.earnedTrophies.platinum > 0
    );

    console.log(`Found ${gamesWithTrophies.length} games with trophies`);
    logMemory('After filtering gamesWithTrophies');

    let processedGames = 0;
    let totalTrophies = 0;

    // Process in batches to avoid OOM and reduce memory footprint
    const BATCH_SIZE = parseInt(options.batchSize, 10) || ENV_BATCH_SIZE;
    const MAX_CONCURRENT = parseInt(options.maxConcurrent, 10) || ENV_MAX_CONCURRENT;
    console.log(`Using BATCH_SIZE=${BATCH_SIZE}, MAX_CONCURRENT=${MAX_CONCURRENT}`);

    for (let i = 0; i < gamesWithTrophies.length; i += BATCH_SIZE) {
      const batch = gamesWithTrophies.slice(i, i + BATCH_SIZE);
      logMemory(`Before processing PSN batch ${i / BATCH_SIZE + 1}`);
      // Run batch sequentially or with limited concurrency
      if (MAX_CONCURRENT <= 1) {
      for (const title of batch) {
        try {
        // Upsert game title
        const { data: game } = await supabase
          .from('game_titles')
          .upsert({
            psn_np_communication_id: title.npCommunicationId,
            name: title.trophyTitleName,
            cover_url: title.trophyTitleIconUrl,
          }, {
            onConflict: 'psn_np_communication_id',
          })
          .select()
          .single();
        // Upsert user_games
        await supabase
          .from('user_games')
          .upsert({
            user_id: userId,
            game_title_id: game.id,
            platform: 'psn',
            progress: title.progress,
          }, {
            onConflict: 'user_id,game_title_id',
          });

        // Fetch and sync trophies
        console.log('Fetching PSN trophies for', title.npCommunicationId);
        const trophyData = await getTitleTrophies(
          { accessToken: currentAccessToken },
          title.npCommunicationId,
          'all',
          { npServiceName: title.npServiceName }
        );
        console.log('Fetched trophies count:', trophyData?.trophies?.length ?? 0);

        for (const trophy of trophyData.trophies) {
          // PSN DLC detection: trophy groups other than 'default' are DLC
          const isDLC = trophy.trophyGroupId && trophy.trophyGroupId !== 'default';
          const dlcName = isDLC ? `DLC Group ${trophy.trophyGroupId}` : null;
          
          // Upsert achievement (PSN trophy)
          const { data: achievementRecord } = await supabase
            .from('achievements')
            .upsert({
              game_title_id: game.id,
              platform: 'psn',
              platform_achievement_id: trophy.trophyId,
              name: trophy.trophyName,
              description: trophy.trophyDetail,
              icon_url: trophy.trophyIconUrl,
              psn_trophy_type: trophy.trophyType,
              psn_trophy_group_id: trophy.trophyGroupId,
              is_dlc: isDLC,
              dlc_name: dlcName,
            }, {
              onConflict: 'game_title_id,platform,platform_achievement_id',
            })
            .select()
            .single();

          if (!achievementRecord) continue;

          // Upsert user_achievement if earned
          if (trophy.earned) {
            await supabase
              .from('user_achievements')
              .upsert({
                user_id: userId,
                achievement_id: achievementRecord.id,
                unlocked_at: trophy.earnedDateTime,
              }, {
                onConflict: 'user_id,achievement_id',
              });
            
            totalTrophies++;
          }
        }

        processedGames++;
        const progress = Math.floor((processedGames / gamesWithTrophies.length) * 100);
        
        // Update progress
        await supabase
          .from('profiles')
          .update({ psn_sync_progress: progress })
          .eq('id', userId);

            console.log(`Processed ${processedGames}/${gamesWithTrophies.length} games (${progress}%)`);
            // brief pause to yield to the event loop
            await new Promise((r) => setTimeout(r, 25));
        } catch (error) {
          console.error(`Error processing title ${title.trophyTitleName}:`, error);
          // Continue with next game
        }
      }
      logMemory(`After processing PSN batch ${i / BATCH_SIZE + 1}`);
      } else {
        const worker = async (titlesChunk) => {
          await Promise.all(titlesChunk.map(async (title) => {
            try {
              const { data: game } = await supabase
                .from('games')
                .upsert({
                  psn_np_communication_id: title.npCommunicationId,
                  title: title.trophyTitleName,
                  platform: title.trophyTitlePlatform,
                  image_url: title.trophyTitleIconUrl,
                }, {
                  onConflict: 'psn_np_communication_id',
                })
                .select()
                .single();

              if (!game) return;

              // Upsert user_game
              await supabase
                .from('user_games')
                .upsert({
                  user_id: userId,
                  game_title_id: game.id,
                  platform: 'psn',
                  progress: title.progress,
                }, {
                  onConflict: 'user_id,game_title_id',
                });

              // Fetch and sync trophies
              console.log('Fetching PSN trophies for', title.npCommunicationId);
              const trophyData = await getTitleTrophies(
                { accessToken: currentAccessToken },
                title.npCommunicationId,
                'all',
                { npServiceName: title.npServiceName }
              );
              console.log('Fetched trophies count:', trophyData?.trophies?.length ?? 0);

              for (const trophy of trophyData.trophies) {
                // Detect DLC based on trophy group
                const isDLC = trophy.trophyGroupId && trophy.trophyGroupId !== 'default';
                const dlcName = isDLC ? `DLC ${trophy.trophyGroupId}` : null;

                // Upsert achievement (PSN trophy)
                const { data: achievementRecord } = await supabase
                  .from('achievements')
                  .upsert({
                    game_title_id: game.id,
                    platform: 'psn',
                    platform_achievement_id: trophy.trophyId,
                    name: trophy.trophyName,
                    description: trophy.trophyDetail,
                    icon_url: trophy.trophyIconUrl,
                    psn_trophy_type: trophy.trophyType,
                    psn_trophy_group_id: trophy.trophyGroupId,
                    is_dlc: isDLC,
                    dlc_name: dlcName,
                  }, {
                    onConflict: 'game_title_id,platform,platform_achievement_id',
                  })
                  .select()
                  .single();

                if (!achievementRecord) return;

                // Upsert user_achievement if earned
                if (trophy.earned) {
                  await supabase
                    .from('user_achievements')
                    .upsert({
                      user_id: userId,
                      achievement_id: achievementRecord.id,
                      unlocked_at: trophy.earnedDateTime,
                    }, {
                      onConflict: 'user_id,achievement_id',
                    });
                  
                  totalTrophies++;
                }
              }
            } catch (error) {
              console.error(`Error processing title ${title.trophyTitleName}:`, error);
            }
          }));
        };

        for (let k = 0; k < batch.length; k += MAX_CONCURRENT) {
          const titlesChunk = batch.slice(k, k + MAX_CONCURRENT);
          await worker(titlesChunk);
        }
      }
    }

    // Mark as completed
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

    console.log(`PSN sync completed: ${processedGames} games, ${totalTrophies} trophies`);

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
