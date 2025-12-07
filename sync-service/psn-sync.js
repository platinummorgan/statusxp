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
        // Map PSN platform codes to our platform codes
        let platformCode = 'PS5'; // Default
        if (title.trophyTitlePlatform) {
          const psnPlatform = title.trophyTitlePlatform.toUpperCase();
          if (psnPlatform.includes('PS5')) platformCode = 'PS5';
          else if (psnPlatform.includes('PS4')) platformCode = 'PS4';
          else if (psnPlatform.includes('PS3')) platformCode = 'PS3';
          else if (psnPlatform.includes('VITA')) platformCode = 'PSVITA';
        }

        // Get platform ID
        const { data: platform } = await supabase
          .from('platforms')
          .select('id')
          .eq('code', platformCode)
          .single();

        if (!platform) {
          console.error(`❌ Platform not found for code ${platformCode} (PSN: ${title.trophyTitlePlatform}), skipping game: ${title.trophyTitleName}`);
          continue;
        }

        // Search for existing game by name (case-insensitive)
        const { data: existingGame } = await supabase
          .from('game_titles')
          .select('id, cover_url')
          .ilike('name', title.trophyTitleName)
          .maybeSingle();

        let gameTitle;
        if (existingGame) {
          // Update cover if missing
          if (!existingGame.cover_url && title.trophyTitleIconUrl) {
            await supabase
              .from('game_titles')
              .update({ cover_url: title.trophyTitleIconUrl })
              .eq('id', existingGame.id);
          }
          gameTitle = existingGame;
        } else {
          // Create new game_title (NO platform_id)
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
            console.error('❌ Failed to insert game_title:', title.trophyTitleName, 'Error:', insertError);
            continue;
          }
          gameTitle = newGame;
        }

        // Check if we need to fetch trophy details (only if new or progress changed)
        const { data: existingUserGame } = await supabase
          .from('user_games')
          .select('completion_percent')
          .eq('user_id', userId)
          .eq('game_title_id', gameTitle.id)
          .eq('platform_id', platform.id)
          .maybeSingle();

        const needsTrophyFetch = !existingUserGame || existingUserGame.completion_percent !== title.progress;

        // Upsert user_games with platform_id
        await supabase
          .from('user_games')
          .upsert({
            user_id: userId,
            game_title_id: gameTitle.id,
            platform_id: platform.id,
            completion_percent: title.progress,
            total_trophies: title.definedTrophies?.bronze + title.definedTrophies?.silver + title.definedTrophies?.gold + title.definedTrophies?.platinum,
            earned_trophies: title.earnedTrophies?.bronze + title.earnedTrophies?.silver + title.earnedTrophies?.gold + title.earnedTrophies?.platinum,
            bronze_trophies: title.earnedTrophies?.bronze || 0,
            silver_trophies: title.earnedTrophies?.silver || 0,
            gold_trophies: title.earnedTrophies?.gold || 0,
            platinum_trophies: title.earnedTrophies?.platinum || 0,
            has_platinum: (title.earnedTrophies?.platinum || 0) > 0,
            last_played_at: title.lastUpdatedDateTime,
          }, {
            onConflict: 'user_id,game_title_id,platform_id',
          });

        // Only fetch trophy details if game is new or progress changed
        if (!needsTrophyFetch) {
          console.log(`⏭️  Skipping trophy fetch for ${title.trophyTitleName} (no changes)`);
          processedGames++;
          continue;
        }

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
              game_title_id: gameTitle.id,
              platform: 'psn',
              platform_achievement_id: trophy.trophyId.toString(),
              name: trophy.trophyName,
              description: trophy.trophyDetail,
              icon_url: trophy.trophyIconUrl,
              psn_trophy_type: trophy.trophyType,
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
                earned_at: trophy.earnedDateTime,
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
              // Map PSN platform codes to our platform codes
              let platformCode = 'PS5'; // Default
              if (title.trophyTitlePlatform) {
                const psnPlatform = title.trophyTitlePlatform.toUpperCase();
                if (psnPlatform.includes('PS5')) platformCode = 'PS5';
                else if (psnPlatform.includes('PS4')) platformCode = 'PS4';
                else if (psnPlatform.includes('PS3')) platformCode = 'PS3';
                else if (psnPlatform.includes('VITA')) platformCode = 'PSVITA';
              }

              // Get platform ID
              const { data: platform } = await supabase
                .from('platforms')
                .select('id')
                .eq('code', platformCode)
                .single();

              if (!platform) {
                console.error(`❌ Platform not found for code ${platformCode} (PSN: ${title.trophyTitlePlatform}), skipping game: ${title.trophyTitleName}`);
                return;
              }

              // Search for existing game by name
              const { data: existingGame } = await supabase
                .from('game_titles')
                .select('id, cover_url')
                .ilike('name', title.trophyTitleName)
                .maybeSingle();

              let gameTitle;
              if (existingGame) {
                // Update cover if missing
                if (!existingGame.cover_url && title.trophyTitleIconUrl) {
                  await supabase
                    .from('game_titles')
                    .update({ cover_url: title.trophyTitleIconUrl })
                    .eq('id', existingGame.id);
                }
                gameTitle = existingGame;
              } else {
                // Create new game_title
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
                  console.error('❌ Failed to insert game_title:', title.trophyTitleName, 'Error:', insertError);
                  return;
                }
                gameTitle = newGame;
              }

              // Check if we need to fetch trophy details (only if new or progress changed)
              const { data: existingUserGame } = await supabase
                .from('user_games')
                .select('completion_percent')
                .eq('user_id', userId)
                .eq('game_title_id', gameTitle.id)
                .eq('platform_id', platform.id)
                .maybeSingle();

              const needsTrophyFetch = !existingUserGame || existingUserGame.completion_percent !== title.progress;

              // Upsert user_games with platform_id
              await supabase
                .from('user_games')
                .upsert({
                  user_id: userId,
                  game_title_id: gameTitle.id,
                  platform_id: platform.id,
                  completion_percent: title.progress,
                  total_trophies: title.definedTrophies?.bronze + title.definedTrophies?.silver + title.definedTrophies?.gold + title.definedTrophies?.platinum,
                  earned_trophies: title.earnedTrophies?.bronze + title.earnedTrophies?.silver + title.earnedTrophies?.gold + title.earnedTrophies?.platinum,
                  bronze_trophies: title.earnedTrophies?.bronze || 0,
                  silver_trophies: title.earnedTrophies?.silver || 0,
                  gold_trophies: title.earnedTrophies?.gold || 0,
                  platinum_trophies: title.earnedTrophies?.platinum || 0,
                  has_platinum: (title.earnedTrophies?.platinum || 0) > 0,
                  last_played_at: title.lastUpdatedDateTime,
                }, {
                  onConflict: 'user_id,game_title_id,platform_id',
                });

              // Only fetch trophy details if game is new or progress changed
              if (!needsTrophyFetch) {
                console.log(`⏭️  Skipping trophy fetch for ${title.trophyTitleName} (no changes)`);
                return;
              }

              // Fetch and sync trophies
              console.log('Fetching PSN trophies for', title.npCommunicationId);
              const trophyData = await getTitleTrophies(
                { accessToken: currentAccessToken },
                title.npCommunicationId,
                'all',
                { npServiceName: title.npServiceName }
              );
              console.log('Fetched trophies count:', trophyData?.trophies?.length ?? 0);
              
              // Log first trophy to see structure
              if (trophyData?.trophies?.length > 0) {
                console.log('[PSN RARITY] First trophy sample:', JSON.stringify(trophyData.trophies[0]));
              }

              for (const trophy of trophyData.trophies) {
                // Detect DLC based on trophy group
                const isDLC = trophy.trophyGroupId && trophy.trophyGroupId !== 'default';
                const dlcName = isDLC ? `DLC ${trophy.trophyGroupId}` : null;
                const rarityPercent = trophy.trophyEarnedRate ? parseFloat(trophy.trophyEarnedRate) : null;
                
                if (rarityPercent !== null && rarityPercent > 0) {
                  console.log(`[PSN RARITY] ${trophy.trophyName}: ${rarityPercent}%`);
                }

                // Upsert achievement (PSN trophy) with rarity data
                const { data: achievementRecord } = await supabase
                  .from('achievements')
                  .upsert({
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
                      earned_at: trophy.earnedDateTime,
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
