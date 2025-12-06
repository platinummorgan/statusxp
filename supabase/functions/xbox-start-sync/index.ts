/**
 * Xbox Start Sync Edge Function
 * 
 * Initiates background sync of Xbox Live achievements
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface StartSyncRequest {
  syncType?: 'full' | 'incremental';
  forceResync?: boolean;
}

/**
 * Refresh Xbox Live tokens if expired
 */
async function refreshXboxToken(
  refreshToken: string,
  supabase: any,
  userId: string
): Promise<{ accessToken: string; xuid: string; userHash: string }> {
  console.log('Refreshing Xbox token...');

  // Step 1: Refresh Microsoft access token
  const tokenResponse = await fetch('https://login.live.com/oauth20_token.srf', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      client_id: '000000004C12AE6F',
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }).toString(),
  });

  if (!tokenResponse.ok) {
    throw new Error('Failed to refresh Microsoft token');
  }

  const tokenData = await tokenResponse.json();
  const msAccessToken = tokenData.access_token;
  const newRefreshToken = tokenData.refresh_token;

  // Step 2: Get Xbox Live user token
  const userTokenResponse = await fetch('https://user.auth.xboxlive.com/user/authenticate', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-xbl-contract-version': '1',
    },
    body: JSON.stringify({
      RelyingParty: 'http://auth.xboxlive.com',
      TokenType: 'JWT',
      Properties: {
        AuthMethod: 'RPS',
        SiteName: 'user.auth.xboxlive.com',
        RpsTicket: `d=${msAccessToken}`,
      },
    }),
  });

  if (!userTokenResponse.ok) {
    throw new Error('Failed to get Xbox user token');
  }

  const userTokenData = await userTokenResponse.json();
  const userToken = userTokenData.Token;

  // Step 3: Get XSTS token
  const xstsTokenResponse = await fetch('https://xsts.auth.xboxlive.com/xsts/authorize', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-xbl-contract-version': '1',
    },
    body: JSON.stringify({
      RelyingParty: 'http://xboxlive.com',
      TokenType: 'JWT',
      Properties: {
        UserTokens: [userToken],
        SandboxId: 'RETAIL',
      },
    }),
  });

  if (!xstsTokenResponse.ok) {
    throw new Error('Failed to get XSTS token');
  }

  const xstsData = await xstsTokenResponse.json();
  const xstsToken = xstsData.Token;
  const userHash = xstsData.DisplayClaims.xui[0].uhs;
  const xuid = xstsData.DisplayClaims.xui[0].xid;

  // Update stored tokens
  const expiresAt = new Date();
  expiresAt.setSeconds(expiresAt.getSeconds() + 86400); // 24 hours

  await supabase
    .from('profiles')
    .update({
      xbox_access_token: xstsToken,
      xbox_user_hash: userHash,
      xbox_refresh_token: newRefreshToken,
      xbox_token_expires_at: expiresAt.toISOString(),
    })
    .eq('id', userId);

  console.log('Xbox token refreshed successfully');

  return {
    accessToken: xstsToken,
    userHash,
    xuid,
  };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!;
    const authHeader = req.headers.get('Authorization')!;

    const supabase = createClient(supabaseUrl, supabaseKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: userError } = await supabase.auth.getUser();

    if (userError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { syncType = 'full', forceResync = false }: StartSyncRequest = await req.json();

    // Get user profile with Xbox credentials
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('xbox_xuid, xbox_user_hash, xbox_access_token, xbox_refresh_token, xbox_token_expires_at, xbox_gamertag, last_xbox_sync_at, xbox_sync_status')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!profile.xbox_xuid || !profile.xbox_access_token) {
      return new Response(JSON.stringify({ error: 'Xbox account not linked' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Check if sync is already in progress
    if (profile.xbox_sync_status === 'syncing') {
      return new Response(
        JSON.stringify({
          error: 'Sync already in progress',
          message: 'A sync is already running. Please wait for it to complete.',
        }),
        {
          status: 409,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // If status is 'pending', resume the existing sync log instead of creating new one
    let syncLog;
    if (profile.xbox_sync_status === 'pending') {
      console.log('Resuming pending sync...');
      const { data: existingLog } = await supabase
        .from('xbox_sync_logs')
        .select()
        .eq('user_id', user.id)
        .eq('status', 'pending')
        .order('started_at', { ascending: false })
        .limit(1)
        .single();
      
      if (existingLog) {
        syncLog = existingLog;
        console.log(`Resuming sync log ID: ${syncLog.id}`);
      }
    }

    console.log(`Starting Xbox sync for user ${user.id} (${profile.xbox_gamertag})`);

    // Always refresh token before sync to ensure fresh credentials
    let accessToken = profile.xbox_access_token;
    let xuid = profile.xbox_xuid;
    let userHash = profile.xbox_user_hash;

    if (!profile.xbox_refresh_token) {
      return new Response(
        JSON.stringify({
          error: 'No refresh token available',
          message: 'Please reconnect your Xbox account',
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    console.log('Refreshing Xbox token before sync...');
    try {
      const refreshed = await refreshXboxToken(profile.xbox_refresh_token, supabase, user.id);
      accessToken = refreshed.accessToken;
      xuid = refreshed.xuid;
      userHash = refreshed.userHash;
      console.log('Token refreshed successfully');
    } catch (error) {
      console.error('Token refresh failed:', error);
      return new Response(
        JSON.stringify({
          error: 'Failed to refresh token',
          message: 'Please reconnect your Xbox account',
          details: error instanceof Error ? error.message : 'Unknown error',
        }),
        {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Create sync log entry (or reuse existing if pending)
    if (!syncLog) {
      const { data: newSyncLog, error: logError } = await supabase
        .from('xbox_sync_logs')
        .insert({
          user_id: user.id,
          sync_type: syncType,
          status: 'pending',
          started_at: new Date().toISOString(),
        })
        .select()
        .single();

      if (logError) {
        console.error('Failed to create sync log:', logError);
        throw logError;
      }

      syncLog = newSyncLog;
    }

    // Update profile sync status
    await supabase
      .from('profiles')
      .update({
        xbox_sync_status: 'pending',
        xbox_sync_progress: 0,
        xbox_sync_error: null,
      })
      .eq('id', user.id);

    // Start background sync process
    syncXboxAchievements(user.id, xuid, userHash, accessToken, syncLog.id, syncType)
      .catch((error) => {
        console.error('Background sync error:', error);
      });

    return new Response(
      JSON.stringify({
        success: true,
        syncLogId: syncLog.id,
        message: 'Xbox sync started successfully',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error starting Xbox sync:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to start Xbox sync',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

/**
 * Background sync process for Xbox achievements
 * Uses batch processing - syncs 5 games per call, auto-resumes
 */
async function syncXboxAchievements(
  userId: string,
  xuid: string,
  userHash: string,
  accessToken: string,
  syncLogId: number,
  syncType: string
) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

  const supabase = createClient(supabaseUrl, supabaseServiceKey);
  
  const BATCH_SIZE = 5; // Process 5 games per call
  const MAX_EXECUTION_TIME = 110000; // 110 seconds (leave buffer for cleanup)
  const startTime = Date.now();

  try {
    console.log(`Xbox sync batch started for user ${userId}, XUID: ${xuid}`);

    // Fetch Xbox achievements
    console.log('Fetching Xbox title history...');
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

    if (!titleHistoryResponse.ok) {
      throw new Error(`Failed to fetch title history: ${titleHistoryResponse.statusText}`);
    }

    const titleHistory = await titleHistoryResponse.json();
    const titles = titleHistory.titles || [];

    console.log(`Found ${titles.length} total Xbox games`);
    
    // Filter to only games with achievement progress
    const gamesWithProgress = titles.filter((title: any) => {
      const currentAchievements = title.achievement?.currentAchievements || 0;
      return currentAchievements > 0;
    });
    
    console.log(`Filtered to ${gamesWithProgress.length} games with earned achievements`);

    // Get games already processed in THIS sync session from sync log
    const { data: processedGamesData } = await supabase
      .from('xbox_sync_logs')
      .select('games_processed_ids')
      .eq('id', syncLogId)
      .single();

    const processedInSession = new Set(processedGamesData?.games_processed_ids || []);
    console.log(`Already processed in this session: ${processedInSession.size} games`);

    // Filter to games NOT YET PROCESSED in this session only
    // We want to sync ALL games to update rarity/scores/new achievements
    const gamesToSync = gamesWithProgress.filter((title: any) => {
      return !processedInSession.has(title.titleId);
    });
    
    console.log(`Remaining games to process this session: ${gamesToSync.length}`);

    // Calculate current progress based on games processed in THIS session
    const currentProgress = gamesWithProgress.length > 0 
      ? Math.min(Math.floor((processedInSession.size / gamesWithProgress.length) * 100), 100) 
      : 0;

    // Take next batch
    const batchTitles = gamesToSync.slice(0, BATCH_SIZE);

    if (batchTitles.length === 0) {
      // All games synced - complete
      console.log('All games already synced!');
      
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
        })
        .eq('id', syncLogId);

      return;
    }

    console.log(`Processing batch of ${batchTitles.length} games... (Current progress: ${currentProgress}%)`);

    // Update status to syncing with current progress
    await supabase
      .from('profiles')
      .update({ 
        xbox_sync_status: 'syncing',
        xbox_sync_progress: currentProgress,
      })
      .eq('id', userId);

    await supabase
      .from('xbox_sync_logs')
      .update({ status: 'syncing' })
      .eq('id', syncLogId);

    let processedGames = 0;
    let totalAchievements = 0;

    for (const title of batchTitles) {
      // Check if approaching timeout
      if (Date.now() - startTime > MAX_EXECUTION_TIME) {
        console.log('Approaching timeout - saving progress and exiting');
        break;
      }

      try {
        console.log(`Title: ${title.name} (${title.titleId})`);
        console.log(`  achievement.totalGamerscore: ${title.achievement?.totalGamerscore}`);
        
        // Find or create game title
        const { data: gameTitle, error: gameTitleError } = await supabase
          .from('game_titles')
          .select('id')
          .eq('xbox_title_id', title.titleId)
          .single();

        let gameTitleId;

        if (gameTitleError || !gameTitle) {
          // Create new game title
          const { data: newGame, error: insertError } = await supabase
            .from('game_titles')
            .insert({
              name: title.name,
              xbox_title_id: title.titleId,
              xbox_max_gamerscore: title.achievement?.totalGamerscore || 0,
              xbox_total_achievements: 0, // Will be updated after fetching achievements
              cover_url: title.displayImage,
            })
            .select('id')
            .single();

          if (insertError) {
            console.error(`Failed to create game title for ${title.name}:`, insertError);
            continue;
          }

          gameTitleId = newGame.id;
        } else {
          gameTitleId = gameTitle.id;
        }

        // Fetch achievements for this title
        const achievementsResponse = await fetch(
          `https://achievements.xboxlive.com/users/xuid(${xuid})/achievements?titleId=${title.titleId}`,
          {
            headers: {
              'x-xbl-contract-version': '4',
              'Accept-Language': 'en-US',
              Authorization: `XBL3.0 x=${userHash};${accessToken}`,
            },
          }
        );

        if (!achievementsResponse.ok) {
          console.error(`Failed to fetch achievements for ${title.name}`);
          continue;
        }

        const achievementsData = await achievementsResponse.json();
        const achievements = achievementsData.achievements || [];
        const totalAchievementsForGame = achievements.length;

        console.log(`Processing ${achievements.length} achievements for ${title.name}`);

        // Fetch global achievement statistics separately
        let globalStatsMap = new Map();
        try {
          const statsResponse = await fetch(
            `https://titlehub.xboxlive.com/titles/${title.titleId}/achievements/stats`,
            {
              headers: {
                'x-xbl-contract-version': '2',
                'Accept-Language': 'en-US',
                Authorization: `XBL3.0 x=${userHash};${accessToken}`,
              },
            }
          );

          if (statsResponse.ok) {
            const statsData = await statsResponse.json();
            console.log(`Global stats response for ${title.name}:`, JSON.stringify(statsData).substring(0, 500));
            
            // Map achievement IDs to their rarity percentages
            if (statsData.achievements) {
              for (const stat of statsData.achievements) {
                if (stat.earnedPercentage !== undefined) {
                  globalStatsMap.set(stat.id, stat.earnedPercentage);
                }
              }
            }
          } else {
            console.log(`Stats endpoint returned ${statsResponse.status} for ${title.name}`);
          }
        } catch (statsError) {
          console.log(`Could not fetch global stats for ${title.name}:`, statsError);
        }

        for (const achievement of achievements) {
          // Get rarity from global stats map
          const rarityPercent = globalStatsMap.get(achievement.id) || 0;
          
          if (rarityPercent > 0) {
            console.log(`${achievement.name}: rarity=${rarityPercent}%`);
          } else {
            console.log(`${achievement.name}: No rarity data available`);
          }


          // Store achievement (upsert with conflict resolution)
          const { data: achievementData, error: achievementError } = await supabase
            .from('achievements')
            .upsert({
              game_title_id: gameTitleId,
              platform: 'xbox',
              platform_achievement_id: achievement.id,
              name: achievement.name,
              description: achievement.description,
              icon_url: achievement.mediaAssets?.[0]?.url,
              xbox_gamerscore: achievement.rewards?.[0]?.value || 0,
              xbox_is_secret: achievement.isSecret || false,
              rarity_global: rarityPercent,
              is_dlc: false, // TODO: Detect DLC achievements
            }, {
              onConflict: 'game_title_id,platform,platform_achievement_id',
              ignoreDuplicates: false,
            })
            .select()
            .single();

          if (achievementError) {
            console.error(`Failed to store achievement ${achievement.name}:`, achievementError);
            continue;
          }

          if (!achievementData) {
            console.error(`No achievement data returned for ${achievement.name}`);
            continue;
          }

          totalAchievements++;

          // Store user achievement if unlocked
          if (achievement.progressState === 'Achieved') {
            const { error: userAchievementError } = await supabase
              .from('user_achievements')
              .upsert({
                user_id: userId,
                achievement_id: achievementData.id,
                platform: 'xbox',
                unlocked_at: achievement.progression?.timeUnlocked || new Date().toISOString(),
                platform_unlock_data: {
                  gamerscore: achievement.rewards?.[0]?.value || 0,
                  rarity: rarityPercent,
                },
              }, {
                onConflict: 'user_id,achievement_id',
                ignoreDuplicates: false,
              });

            if (userAchievementError) {
              console.error(`Failed to store user achievement:`, userAchievementError);
            }
          }
        }

        // Update game_titles with achievement count and gamerscore
        await supabase
          .from('game_titles')
          .update({ 
            xbox_total_achievements: totalAchievementsForGame,
            xbox_max_gamerscore: title.achievement?.totalGamerscore || 0,
          })
          .eq('id', gameTitleId);

        // Store user_games entry with Xbox stats
        const currentAchievements = title.achievement?.currentAchievements || 0;
        const currentGamerscore = title.achievement?.currentGamerscore || 0;
        const totalGamerscore = title.achievement?.totalGamerscore || 0;
        const completionPercent = totalAchievementsForGame > 0 
          ? Math.floor((currentAchievements / totalAchievementsForGame) * 100)
          : 0;

        await supabase
          .from('user_games')
          .upsert({
            user_id: userId,
            game_title_id: gameTitleId,
            platform: 'xbox',
            total_trophies: totalAchievementsForGame, // Required field - using actual achievement count
            earned_trophies: currentAchievements,   // Required field - using earned achievements
            completion_percent: completionPercent,
            xbox_current_gamerscore: currentGamerscore,
            xbox_max_gamerscore: totalGamerscore,
            xbox_achievements_earned: currentAchievements,
            xbox_total_achievements: totalAchievementsForGame, // Use actual count from achievements API
            xbox_last_updated_at: new Date().toISOString(),
            last_played_at: title.lastUnlock || null,
          }, {
            onConflict: 'user_id,game_title_id,platform',
            ignoreDuplicates: false,
          });

        processedGames++;
        // Track this game as processed in this session
        processedInSession.add(title.titleId);

      } catch (gameError) {
        console.error(`Error processing game ${title.name}:`, gameError);
        // Still mark as processed to avoid infinite retry on same game
        processedInSession.add(title.titleId);
      }
    }

    // Calculate progress based on games processed in THIS session
    const progress = gamesWithProgress.length > 0 
      ? Math.min(Math.floor((processedInSession.size / gamesWithProgress.length) * 100), 100) 
      : 100;

    console.log(`Batch complete: ${processedGames} games processed. Total progress: ${processedInSession.size}/${gamesWithProgress.length} (${progress}%)`);

    // CRITICAL: Always update processed games and set status, even if errors occurred
    try {
      // Update sync log with processed games
      await supabase
        .from('xbox_sync_logs')
        .update({ 
          games_processed_ids: Array.from(processedInSession),
          games_processed: processedGames,
          achievements_synced: totalAchievements,
        })
        .eq('id', syncLogId);

      // Check if more games remain
      if (gamesToSync.length > BATCH_SIZE) {
        // More games to process - mark as pending for auto-resume
        console.log(`${gamesToSync.length - BATCH_SIZE} games remaining - status set to pending for next batch`);
        
        const { error: profileUpdateError } = await supabase
          .from('profiles')
          .update({
            xbox_sync_status: 'pending',
            xbox_sync_progress: progress,
          })
          .eq('id', userId);

        if (profileUpdateError) {
          console.error('CRITICAL: Failed to update profile status to pending:', profileUpdateError);
        } else {
          console.log('Successfully set profile status to pending');
        }

        const { error: logUpdateError } = await supabase
          .from('xbox_sync_logs')
          .update({ status: 'pending' })
          .eq('id', syncLogId);

        if (logUpdateError) {
          console.error('CRITICAL: Failed to update sync log status:', logUpdateError);
        }
      } else {
        // All games synced - complete
        console.log('All games synced - marking as success');
        
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
      }
    } catch (updateError) {
      console.error('CRITICAL: Failed to update sync status:', updateError);
      // Force set to pending so it can retry
      await supabase
        .from('profiles')
        .update({ xbox_sync_status: 'pending', xbox_sync_progress: progress })
        .eq('id', userId);
    }

  } catch (error) {
    console.error('Xbox sync failed:', error);

    await supabase
      .from('profiles')
      .update({
        xbox_sync_status: 'error',
        xbox_sync_error: error instanceof Error ? error.message : 'Unknown error',
      })
      .eq('id', userId);

    await supabase
      .from('xbox_sync_logs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: error instanceof Error ? error.message : 'Unknown error',
      })
      .eq('id', syncLogId);
  }
}
