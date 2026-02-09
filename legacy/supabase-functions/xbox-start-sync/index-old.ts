/**
 * Xbox Start Sync Edge Function
 *
 * Initiates background sync of Xbox Live achievements using a consistent
 * structure shared by the PSN and Steam implementations.
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

interface StartSyncRequest {
  syncType?: 'full' | 'incremental';
  forceResync?: boolean;
}

interface SupabaseProfile {
  xbox_xuid: string;
  xbox_user_hash: string;
  xbox_access_token: string;
  xbox_refresh_token: string;
  xbox_token_expires_at: string;
  xbox_gamertag: string;
  last_xbox_sync_at: string | null;
  xbox_sync_status: string | null;
}

function jsonResponse(body: unknown, init?: ResponseInit) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function getSupabaseClient(authHeader: string) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')!;

  return createClient(supabaseUrl, supabaseKey, {
    global: { headers: { Authorization: authHeader } },
  });
}

async function getAuthenticatedUser(supabase: any) {
  const {
    data: { user },
    error,
  } = await supabase.auth.getUser();
  if (error || !user) {
    throw new Error('Unauthorized');
  }
  return user;
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

  const tokenResponse = await fetch('https://login.live.com/oauth20_token.srf', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
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

  const userTokenResponse = await fetch(
    'https://user.auth.xboxlive.com/user/authenticate',
    {
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
    }
  );

  if (!userTokenResponse.ok) {
    throw new Error('Failed to get Xbox user token');
  }

  const userTokenData = await userTokenResponse.json();
  const userToken = userTokenData.Token;

  const xstsTokenResponse = await fetch(
    'https://xsts.auth.xboxlive.com/xsts/authorize',
    {
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
    }
  );

  if (!xstsTokenResponse.ok) {
    throw new Error('Failed to get XSTS token');
  }

  const xstsData = await xstsTokenResponse.json();
  const xstsToken = xstsData.Token;
  const userHash = xstsData.DisplayClaims.xui[0].uhs;
  const xuid = xstsData.DisplayClaims.xui[0].xid;

  const expiresAt = new Date();
  expiresAt.setSeconds(expiresAt.getSeconds() + 86400);

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

  return { accessToken: xstsToken, userHash, xuid };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return jsonResponse({ error: 'Unauthorized' }, { status: 401 });
    }

    const supabase = getSupabaseClient(authHeader);
    const user = await getAuthenticatedUser(supabase);
    const { syncType = 'full', forceResync = false }: StartSyncRequest =
      (await req.json()) || {};

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select(
        'xbox_xuid, xbox_user_hash, xbox_access_token, xbox_refresh_token, xbox_token_expires_at, xbox_gamertag, last_xbox_sync_at, xbox_sync_status'
      )
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      return jsonResponse({ error: 'Profile not found' }, { status: 404 });
    }

    if (!profile.xbox_xuid || !profile.xbox_access_token) {
      return jsonResponse({ error: 'Xbox account not linked' }, { status: 400 });
    }

    if (profile.xbox_sync_status === 'syncing') {
      return jsonResponse(
        {
          error: 'Sync already in progress',
          message: 'A sync is already running. Please wait for it to complete.',
        },
        { status: 409 }
      );
    }

    // Check if there's a pending sync from a previous session
    // If the user is starting a new sync, we should complete the old one first or start fresh
    let syncLog;
    console.log(`Checking for existing pending sync log...`);
    const { data: existingLog } = await supabase
      .from('xbox_sync_logs')
      .select('id, user_id, sync_type, status, started_at, completed_at, games_processed, achievements_synced, games_processed_ids, error_message, created_at')
      .eq('user_id', user.id)
      .eq('status', 'pending')
      .order('started_at', { ascending: false })
      .limit(1)
      .single();
    
    if (existingLog && profile.xbox_sync_status === 'pending') {
      // Only resume if the profile status is also 'pending' (meaning it's actively syncing)
      console.log(`Found existing pending sync log to resume: ${existingLog.id}, processed games: ${existingLog.games_processed_ids?.length || 0}`);
      syncLog = existingLog;
    } else {
      // If there's an old pending log but profile isn't 'pending', mark ALL pending logs as failed and start fresh
      if (existingLog) {
        console.log(`Found stale pending sync logs - marking ALL as failed and starting fresh`);
        await supabase
          .from('xbox_sync_logs')
          .update({ 
            status: 'failed', 
            completed_at: new Date().toISOString(),
            error_message: 'Sync abandoned - new sync started'
          })
          .eq('user_id', user.id)
          .eq('status', 'pending');
      }
      console.log('Starting fresh sync from 0%');
    }

    console.log(`Starting Xbox sync for user ${user.id} (${profile.xbox_gamertag})`);
    console.log(`Using sync log: ${syncLog ? `Existing #${syncLog.id}` : 'Will create new'}`);

    let accessToken = profile.xbox_access_token;
    let xuid = profile.xbox_xuid;
    let userHash = profile.xbox_user_hash;

    if (!profile.xbox_refresh_token) {
      return jsonResponse(
        {
          error: 'No refresh token available',
          message: 'Please reconnect your Xbox account',
        },
        { status: 401 }
      );
    }

    try {
      const refreshed = await refreshXboxToken(
        profile.xbox_refresh_token,
        supabase,
        user.id
      );
      accessToken = refreshed.accessToken;
      xuid = refreshed.xuid;
      userHash = refreshed.userHash;
    } catch (error) {
      console.error('Token refresh failed:', error);
      return jsonResponse(
        {
          error: 'Failed to refresh token',
          message: 'Please reconnect your Xbox account',
          details: error instanceof Error ? error.message : 'Unknown error',
        },
        { status: 401 }
      );
    }

    if (!syncLog) {
      console.log('Creating NEW sync log');
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
        throw logError;
      }
      syncLog = newSyncLog;
      console.log(`Created new sync log with ID: ${syncLog.id}`);
      
      // Only reset progress when creating a NEW sync log
      await supabase
        .from('profiles')
        .update({
          xbox_sync_status: 'pending',
          xbox_sync_progress: 0,
          xbox_sync_error: null,
        })
        .eq('id', user.id);
    } else {
      console.log(`Reusing existing sync log ID: ${syncLog.id}`);
      // When resuming, clear any previous error but keep the existing progress
      await supabase
        .from('profiles')
        .update({
          xbox_sync_error: null,
        })
        .eq('id', user.id);
    }

    syncXboxAchievements(
      user.id,
      xuid,
      userHash,
      accessToken,
      syncLog.id,
      syncType
    ).catch((error) => console.error('Background sync error:', error));

    return jsonResponse({
      success: true,
      syncLogId: syncLog.id,
      message: 'Xbox sync started successfully',
    });
  } catch (error) {
    console.error('Error starting Xbox sync:', error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Failed to start Xbox sync' },
      { status: 500 }
    );
  }
});

/**
 * Background sync process for Xbox achievements
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

  const BATCH_SIZE = 50; // Increased from 5 to 50 - process way more games per batch
  const MAX_EXECUTION_TIME = 110000;
  const startTime = Date.now();

  try {
    console.log(`Xbox sync batch started for user ${userId}, XUID: ${xuid}`);

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

    const gamesWithProgress = titles.filter((title: any) => {
      const currentAchievements = title.achievement?.currentAchievements || 0;
      return currentAchievements > 0;
    });

    const { data: processedGamesData } = await supabase
      .from('xbox_sync_logs')
      .select('games_processed_ids')
      .eq('id', syncLogId)
      .single();

    const processedInSession = new Set(processedGamesData?.games_processed_ids || []);
    const gamesToSync = gamesWithProgress.filter((title: any) => {
      return !processedInSession.has(title.titleId);
    });

    console.log(`=== SYNC BATCH STARTING ===`);
    console.log(`Total games with progress: ${gamesWithProgress.length}`);
    console.log(`Already processed: ${processedInSession.size}`);
    console.log(`Games to sync: ${gamesToSync.length}`);
    console.log(`Batch size: ${BATCH_SIZE}`);
    console.log(`Games in this batch: ${Math.min(gamesToSync.length, BATCH_SIZE)}`);

    const currentProgress =
      gamesWithProgress.length > 0
        ? Math.min(
            Math.floor((processedInSession.size / gamesWithProgress.length) * 100),
            100
          )
        : 0;

    const batchTitles = gamesToSync.slice(0, BATCH_SIZE);

    if (batchTitles.length === 0) {
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
        .update({ status: 'completed', completed_at: new Date().toISOString() })
        .eq('id', syncLogId);
      return;
    }

    await supabase
      .from('profiles')
      .update({ xbox_sync_status: 'syncing', xbox_sync_progress: currentProgress })
      .eq('id', userId);

    await supabase.from('xbox_sync_logs').update({ status: 'syncing' }).eq('id', syncLogId);

    let processedGames = 0;
    let totalAchievements = 0;

    for (const title of batchTitles) {
      if (Date.now() - startTime > MAX_EXECUTION_TIME) {
        console.log('Approaching timeout - saving progress and exiting');
        break;
      }

      try {
        const { data: gameTitle, error: gameTitleError } = await supabase
          .from('game_titles')
          .select('id')
          .eq('xbox_title_id', title.titleId)
          .single();

        let gameTitleId;
        if (gameTitleError || !gameTitle) {
          const { data: newGame, error: insertError } = await supabase
            .from('game_titles')
            .insert({
              name: title.name,
              xbox_title_id: title.titleId,
              xbox_max_gamerscore: title.achievement?.totalGamerscore || 0,
              xbox_total_achievements: 0,
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

        const globalStatsMap = new Map();
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
          const rarityPercent = globalStatsMap.get(achievement.id) || 0;

          const { data: achievementData, error: achievementError } = await supabase
            .from('achievements')
            .upsert(
              {
                game_title_id: gameTitleId,
                platform: 'xbox',
                platform_achievement_id: achievement.id,
                name: achievement.name,
                description: achievement.description,
                icon_url: achievement.mediaAssets?.[0]?.url,
                xbox_gamerscore: achievement.rewards?.[0]?.value || 0,
                xbox_is_secret: achievement.isSecret || false,
                rarity_global: rarityPercent,
                is_dlc: false,
              },
              {
                onConflict: 'game_title_id,platform,platform_achievement_id',
                ignoreDuplicates: false,
              }
            )
            .select()
            .single();

          if (achievementError || !achievementData) {
            console.error(
              `Failed to store achievement ${achievement.name}:`,
              achievementError
            );
            continue;
          }

          totalAchievements++;

          if (achievement.progressState === 'Achieved') {
            const { error: userAchievementError } = await supabase
              .from('user_achievements')
              .upsert(
                {
                  user_id: userId,
                  achievement_id: achievementData.id,
                  platform: 'xbox',
                  unlocked_at:
                    achievement.progression?.timeUnlocked || new Date().toISOString(),
                  platform_unlock_data: {
                    gamerscore: achievement.rewards?.[0]?.value || 0,
                    rarity: rarityPercent,
                  },
                },
                { onConflict: 'user_id,achievement_id', ignoreDuplicates: false }
              );

            if (userAchievementError) {
              console.error('Failed to store user achievement:', userAchievementError);
            }
          }
        }

        await supabase
          .from('game_titles')
          .update({
            xbox_total_achievements: totalAchievementsForGame,
            xbox_max_gamerscore: title.achievement?.totalGamerscore || 0,
          })
          .eq('id', gameTitleId);

        const currentAchievements = title.achievement?.currentAchievements || 0;
        const currentGamerscore = title.achievement?.currentGamerscore || 0;
        const totalGamerscore = title.achievement?.totalGamerscore || 0;
        const completionPercent =
          totalAchievementsForGame > 0
            ? Math.floor((currentAchievements / totalAchievementsForGame) * 100)
            : 0;

        await supabase
          .from('user_games')
          .upsert(
            {
              user_id: userId,
              game_title_id: gameTitleId,
              platform: 'xbox',
              total_trophies: totalAchievementsForGame,
              earned_trophies: currentAchievements,
              completion_percent: completionPercent,
              xbox_current_gamerscore: currentGamerscore,
              xbox_max_gamerscore: totalGamerscore,
              xbox_achievements_earned: currentAchievements,
              xbox_total_achievements: totalAchievementsForGame,
              xbox_last_updated_at: new Date().toISOString(),
              last_played_at: title.lastUnlock || null,
            },
            { onConflict: 'user_id,game_title_id,platform', ignoreDuplicates: false }
          );

        processedGames++;
        processedInSession.add(title.titleId);
      } catch (gameError) {
        console.error(`Error processing game ${title.name}:`, gameError);
        processedInSession.add(title.titleId);
      }
    }

    const progress =
      gamesWithProgress.length > 0
        ? Math.min(
            Math.floor((processedInSession.size / gamesWithProgress.length) * 100),
            100
          )
        : 100;

    console.log(`=== SYNC BATCH COMPLETE ===`);
    console.log(`Total games with progress: ${gamesWithProgress.length}`);
    console.log(`Games processed in session: ${processedInSession.size}`);
    console.log(`Games processed this batch: ${processedGames}`);
    console.log(`Progress: ${progress}%`);
    console.log(`Processed IDs: ${Array.from(processedInSession).join(', ')}`);

    try {
      const updateResult = await supabase
        .from('xbox_sync_logs')
        .update({
          games_processed_ids: Array.from(processedInSession),
          games_processed: processedGames,
          achievements_synced: totalAchievements,
        })
        .eq('id', syncLogId)
        .select();

      console.log(`Update result for sync log ${syncLogId}:`, updateResult);
      
      if (updateResult.error) {
        console.error('CRITICAL: Failed to update games_processed_ids:', updateResult.error);
      } else {
        console.log(`Successfully saved ${processedInSession.size} processed game IDs to database`);
      }

      // Check if there are more games to process (total remaining games vs what we can process in one batch)
      const hasMoreGames = processedInSession.size < gamesWithProgress.length;
      
      console.log(`Has more games to sync: ${hasMoreGames} (${processedInSession.size} < ${gamesWithProgress.length})`);
      
      if (hasMoreGames) {
        console.log('Setting status to PENDING for auto-resume');
        await supabase
          .from('profiles')
          .update({ xbox_sync_status: 'pending', xbox_sync_progress: progress })
          .eq('id', userId);

        await supabase.from('xbox_sync_logs').update({ status: 'pending' }).eq('id', syncLogId);
      } else {
        console.log('All games synced! Setting status to SUCCESS');
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