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

async function refreshXboxToken(refreshToken, userId) {
  const tokenResponse = await fetch('https://login.live.com/oauth20_token.srf', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: process.env.XBOX_CLIENT_ID,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
      scope: 'Xboxlive.signin Xboxlive.offline_access',
    }),
  });

  if (!tokenResponse.ok) {
    const body = await tokenResponse.text();
    console.error('Failed to refresh Xbox token. Status:', tokenResponse.status, 'Body:', body);
    throw new Error('Failed to refresh Xbox token');
  }

  const tokenData = await tokenResponse.json();

  // Exchange for Xbox Live token
  const xblResponse = await fetch('https://user.auth.xboxlive.com/user/authenticate', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      RelyingParty: 'http://auth.xboxlive.com',
      TokenType: 'JWT',
      Properties: {
        AuthMethod: 'RPS',
        SiteName: 'user.auth.xboxlive.com',
        RpsTicket: `d=${tokenData.access_token}`,
      },
    }),
  });

  const xblData = await xblResponse.json();
  console.log('XBL auth response (xblData) keys:', Object.keys(xblData));
  const userHash = xblData.DisplayClaims.xui[0].uhs;

  // Exchange for XSTS token
  const xstsResponse = await fetch('https://xsts.auth.xboxlive.com/xsts/authorize', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      RelyingParty: 'http://xboxlive.com',
      TokenType: 'JWT',
      Properties: {
        UserTokens: [xblData.Token],
        SandboxId: 'RETAIL',
      },
    }),
  });

  const xstsData = await xstsResponse.json();
  console.log('XSTS response status:', xstsResponse.status);
  const xuid = xstsData.DisplayClaims.xui[0].xid;

  // Save to database
  const updateProfile = await supabase
    .from('profiles')
    .update({
      xbox_access_token: xstsData.Token,
      xbox_refresh_token: tokenData.refresh_token,
      xbox_xuid: xuid,
      xbox_user_hash: userHash,
    })
    .eq('id', userId);
  console.log('Saved refreshed tokens to profiles result:', updateProfile.error || 'OK');

  return {
    accessToken: xstsData.Token,
    xuid,
    userHash,
  };
}

export async function syncXboxAchievements(userId, xuid, userHash, accessToken, refreshToken, syncLogId, options = {}) {
  console.log(`Starting Xbox sync for user ${userId}, syncLogId=${syncLogId}`);
  
  try {
    // Refresh token first
    const refreshed = await refreshXboxToken(refreshToken, userId);
    accessToken = refreshed.accessToken;
    xuid = refreshed.xuid;
    userHash = refreshed.userHash;

    // Set initial status
    const profileUpdateRes = await supabase
      .from('profiles')
      .update({ xbox_sync_status: 'syncing', xbox_sync_progress: 0 })
      .eq('id', userId);
    console.log('Set profile to syncing:', profileUpdateRes.error || 'OK');

    await supabase
      .from('xbox_sync_logs')
      .update({ status: 'syncing' })
      .eq('id', syncLogId);

    // Calculate actual values from env and options
    const BATCH_SIZE = parseInt(options.batchSize, 10) || ENV_BATCH_SIZE;
    const MAX_CONCURRENT = parseInt(options.maxConcurrent, 10) || ENV_MAX_CONCURRENT;

    console.log(`Using BATCH_SIZE=${BATCH_SIZE}, MAX_CONCURRENT=${MAX_CONCURRENT}`);

    // Fetch all games
    const titleHistoryResponse = await fetch(
      `https://titlehub.xboxlive.com/users/xuid(${xuid})/titles/titlehistory/decoration/achievement`,
      {
        headers: {
          'x-xbl-contract-version': '2',
          'Accept-Language': 'en-US',
          Authorization: `XBL3.0 x=${userHash};${accessToken}`,
        },
      }
    );

    const titleHistory = await titleHistoryResponse.json();
    console.log('Fetched title history - titles length:', (titleHistory?.titles || []).length);
    
    if (!titleHistory?.titles || titleHistory.titles.length === 0) {
      console.log('No Xbox titles found - marking sync as success with 0 games');
      await supabase
        .from('profiles')
        .update({
          xbox_sync_status: 'success',
          xbox_sync_progress: 100,
          last_xbox_sync_at: new Date().toISOString(),
        })
        .eq('id', userId);

      await supabase
        .from('xbox_sync_logs')
        .update({
          status: 'completed',
          completed_at: new Date().toISOString(),
          games_processed: 0,
          achievements_synced: 0,
        })
        .eq('id', syncLogId);
      return;
    }

    const gamesWithProgress = titleHistory.titles.filter(t => t.achievement?.currentGamerscore > 0);

    console.log(`Found ${gamesWithProgress.length} games with achievements`);
    logMemory('After filtering gamesWithProgress');

    let processedGames = 0;
    let totalAchievements = 0;

    // Process in batches to avoid OOM and reduce memory footprint
    // NOTE: BATCH_SIZE configurable via env var
    for (let i = 0; i < gamesWithProgress.length; i += BATCH_SIZE) {
      const batch = gamesWithProgress.slice(i, i + BATCH_SIZE);
      logMemory(`Before processing batch ${i / BATCH_SIZE + 1}`);
      // Process the batch with limited concurrency to reduce memory spikes
      // If MAX_CONCURRENT === 1 we'll process sequentially.
      if (MAX_CONCURRENT <= 1) {
        for (const title of batch) {
          try {
            console.log(`Processing game: ${title.name} (${title.titleId})`);
            // Upsert game
            const { data: game } = await supabase
              .from('games')
              .upsert({
                xbox_title_id: title.titleId,
                title: title.name,
                platform: 'xbox',
                image_url: title.displayImage,
              }, {
                onConflict: 'xbox_title_id',
              })
              .select()
              .single();

            if (!game) { console.log('Upserted game - no result'); continue; }

            // Upsert user_games
            await supabase
              .from('user_games')
              .upsert({
                user_id: userId,
                game_id: game.id,
                platform: 'xbox',
                gamerscore: title.achievement.currentGamerscore,
                total_gamerscore: title.achievement.totalGamerscore,
                achievements_unlocked: title.achievement.currentAchievements,
                total_achievements: title.achievement.totalAchievements,
                progress: title.achievement.progressPercentage,
              }, {
                onConflict: 'user_id,game_id',
              });

            // Fetch achievements
            const achievementsResponse = await fetch(
              `https://achievements.xboxlive.com/users/xuid(${xuid})/achievements?titleId=${title.titleId}`,
              {
                headers: {
                  'x-xbl-contract-version': '2',
                  Authorization: `XBL3.0 x=${userHash};${accessToken}`,
                },
              }
            );

            const achievementsData = await achievementsResponse.json();
            console.log('Fetched achievements count for titleId', title.titleId, ':', achievementsData?.achievements?.length ?? 0);

            for (const achievement of achievementsData.achievements) {
              // Upsert achievement
              const { data: achievementRecord } = await supabase
                .from('achievements')
                .upsert({
                  game_id: game.id,
                  xbox_achievement_id: achievement.id,
                  name: achievement.name,
                  description: achievement.description,
                  gamerscore: achievement.rewards?.[0]?.value || 0,
                  icon_locked_url: achievement.mediaAssets?.[0]?.url,
                  icon_unlocked_url: achievement.mediaAssets?.[0]?.url,
                }, {
                  onConflict: 'game_id,xbox_achievement_id',
                })
                .select()
                .single();

              if (!achievementRecord) continue;

              // Upsert user_achievement if unlocked
              if (achievement.progressState === 'Achieved') {
                await supabase
                  .from('user_achievements')
                  .upsert({
                    user_id: userId,
                    achievement_id: achievementRecord.id,
                    unlocked_at: achievement.progression?.timeUnlocked,
                  }, {
                    onConflict: 'user_id,achievement_id',
                  });
                
                totalAchievements++;
              }
            }

            processedGames++;
            const progress = Math.floor((processedGames / gamesWithProgress.length) * 100);
            
            // Update progress
            await supabase
              .from('profiles')
              .update({ xbox_sync_progress: progress })
              .eq('id', userId);

            console.log(`Processed ${processedGames}/${gamesWithProgress.length} games (${progress}%)`);
            // Briefly yield to the event loop to reduce temporary memory spikes
            await new Promise((r) => setTimeout(r, 25));
          } catch (error) {
            console.error(`Error processing title ${title.name}:`, error);
            // Continue with next game
          }
        }
      } else {
        // Run with concurrency in parallel chunks
        const worker = async (titlesChunk) => {
          await Promise.all(titlesChunk.map(async (title) => {
            try {
              console.log(`Processing game: ${title.name} (${title.titleId})`);
              // Upsert game + user_games and achievements (same as above)
              const { data: game } = await supabase
                .from('games')
                .upsert({
                  xbox_title_id: title.titleId,
                  title: title.name,
                  platform: 'xbox',
                  image_url: title.displayImage,
                }, {
                  onConflict: 'xbox_title_id',
                })
                .select()
                .single();

              if (!game) { console.log('Upserted game - no result'); return; }

              // Upsert user_games
              await supabase
                .from('user_games')
                .upsert({
                  user_id: userId,
                  game_id: game.id,
                  platform: 'xbox',
                  gamerscore: title.achievement.currentGamerscore,
                  total_gamerscore: title.achievement.totalGamerscore,
                  achievements_unlocked: title.achievement.currentAchievements,
                  total_achievements: title.achievement.totalAchievements,
                  progress: title.achievement.progressPercentage,
                }, {
                  onConflict: 'user_id,game_id',
                });

              // Fetch achievements
              const achievementsResponse = await fetch(
                `https://achievements.xboxlive.com/users/xuid(${xuid})/achievements?titleId=${title.titleId}`,
                {
                  headers: {
                    'x-xbl-contract-version': '2',
                    Authorization: `XBL3.0 x=${userHash};${accessToken}`,
                  },
                }
              );

              const achievementsData = await achievementsResponse.json();

              for (const achievement of achievementsData.achievements) {
                const { data: achievementRecord } = await supabase
                  .from('achievements')
                  .upsert({
                    game_id: game.id,
                    xbox_achievement_id: achievement.id,
                    name: achievement.name,
                    description: achievement.description,
                    gamerscore: achievement.rewards?.[0]?.value || 0,
                    icon_locked_url: achievement.mediaAssets?.[0]?.url,
                    icon_unlocked_url: achievement.mediaAssets?.[0]?.url,
                  }, {
                    onConflict: 'game_id,xbox_achievement_id',
                  })
                  .select()
                  .single();

                if (!achievementRecord) continue;

                if (achievement.progressState === 'Achieved') {
                  await supabase
                    .from('user_achievements')
                    .upsert({
                      user_id: userId,
                      achievement_id: achievementRecord.id,
                      unlocked_at: achievement.progression?.timeUnlocked,
                    }, {
                      onConflict: 'user_id,achievement_id',
                    });
                  totalAchievements++;
                }
              }

              processedGames++;
              const progress = Math.floor((processedGames / gamesWithProgress.length) * 100);
              await supabase
                .from('profiles')
                .update({ xbox_sync_progress: progress })
                .eq('id', userId);
            } catch (error) {
              console.error(`Error processing title ${title.name}:`, error);
            }
          }));
        };

        for (let k = 0; k < batch.length; k += MAX_CONCURRENT) {
          const titlesChunk = batch.slice(k, k + MAX_CONCURRENT);
          await worker(titlesChunk);
        }
      // end inner try-catch for title
      }
      // free batch memory
      // eslint-disable-next-line no-unused-vars
      // Note: local 'batch' will be GC'd when out of scope; explicit null helps
      // eslint-disable-next-line no-param-reassign
      // not reassigning but just log
      logMemory(`After processing batch ${i / BATCH_SIZE + 1}`);
    }

    // Mark as completed
    await supabase
      .from('profiles')
      .update({
        xbox_sync_status: 'success',
        xbox_sync_progress: 100,
        last_xbox_sync_at: new Date().toISOString(),
      })
      .eq('id', userId);

    await supabase
      .from('xbox_sync_logs')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        games_processed: processedGames,
        achievements_synced: totalAchievements,
      })
      .eq('id', syncLogId);

    console.log(`Xbox sync completed: ${processedGames} games, ${totalAchievements} achievements`);

  } catch (error) {
    console.error('Xbox sync failed:', error);
    
    await supabase
      .from('profiles')
      .update({
        xbox_sync_status: 'error',
        xbox_sync_error: error.message,
      })
      .eq('id', userId);

    await supabase
      .from('xbox_sync_logs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: error.message,
      })
      .eq('id', syncLogId);
  }
}
