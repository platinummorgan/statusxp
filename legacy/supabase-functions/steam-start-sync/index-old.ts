/**
 * Steam Start Sync Edge Function
 *
 * Aligns with the structure used for Xbox and PSN sync logic, improving
 * readability and maintenance.
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

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

    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('steam_id, steam_api_key, steam_sync_status')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      return jsonResponse({ error: 'Profile not found' }, { status: 404 });
    }

    if (!profile.steam_id || !profile.steam_api_key) {
      return jsonResponse({ error: 'Steam account not linked' }, { status: 400 });
    }

    if (profile.steam_sync_status === 'syncing') {
      return jsonResponse(
        {
          error: 'Sync already in progress',
          message: 'A sync is already running. Please wait for it to complete.',
        },
        { status: 409 }
      );
    }

    const { data: syncLog, error: logError } = await supabase
      .from('steam_sync_logs')
      .insert({
        user_id: user.id,
        sync_type: 'full',
        status: 'pending',
        started_at: new Date().toISOString(),
      })
      .select()
      .single();

    if (logError) {
      throw logError;
    }

    await supabase
      .from('profiles')
      .update({
        steam_sync_status: 'pending',
        steam_sync_progress: 0,
        steam_sync_error: null,
      })
      .eq('id', user.id);

    syncSteamAchievements(user.id, profile.steam_id, profile.steam_api_key, syncLog.id).catch(
      (error) => console.error('Background sync error:', error)
    );

    return jsonResponse({
      success: true,
      syncLogId: syncLog.id,
      message: 'Steam sync started successfully',
    });
  } catch (error) {
    console.error('Error starting Steam sync:', error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Failed to start Steam sync' },
      { status: 500 }
    );
  }
});

async function syncSteamAchievements(
  userId: string,
  steamId: string,
  apiKey: string,
  syncLogId: number
) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  const BATCH_SIZE = 5;

  try {
    console.log(`Steam sync batch started for user ${userId}, Steam ID: ${steamId}`);

    const gamesResponse = await fetch(
      `https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=${apiKey}&steamid=${steamId}&include_appinfo=1&include_played_free_games=1&format=json`
    );

    if (!gamesResponse.ok) {
      throw new Error(`Failed to fetch Steam games: ${gamesResponse.statusText}`);
    }

    const gamesData = await gamesResponse.json();
    const games = gamesData.response?.games || [];
    const gamesWithAchievements = games.filter((game: any) => game.has_community_visible_stats);

    const { data: processedGamesData } = await supabase
      .from('steam_sync_logs')
      .select('games_processed_ids')
      .eq('id', syncLogId)
      .single();

    const processedInSession = new Set(processedGamesData?.games_processed_ids || []);
    const gamesToSync = gamesWithAchievements.filter((game: any) => {
      return !processedInSession.has(String(game.appid));
    });

    const currentProgress =
      gamesWithAchievements.length > 0
        ? Math.min(
            Math.floor((processedInSession.size / gamesWithAchievements.length) * 100),
            100
          )
        : 0;

    const batchGames = gamesToSync.slice(0, BATCH_SIZE);
    if (batchGames.length === 0) {
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
        .update({ status: 'completed', completed_at: new Date().toISOString() })
        .eq('id', syncLogId);
      return;
    }

    await supabase
      .from('profiles')
      .update({ steam_sync_status: 'syncing', steam_sync_progress: currentProgress })
      .eq('id', userId);

    await supabase.from('steam_sync_logs').update({ status: 'syncing' }).eq('id', syncLogId);

    let processedGames = 0;

    for (const game of batchGames) {
      try {
        let { data: gameTitle } = await supabase
          .from('game_titles')
          .select('id')
          .eq('steam_app_id', game.appid)
          .single();

        let gameTitleId: number;
        if (!gameTitle) {
          const { data: newGame, error: insertError } = await supabase
            .from('game_titles')
            .insert({
              name: game.name,
              platform: 'steam',
              steam_app_id: game.appid,
              cover_url: `https://steamcdn-a.akamaihd.net/steam/apps/${game.appid}/header.jpg`,
            })
            .select('id')
            .single();

          if (insertError) {
            console.error(`Failed to create game title for ${game.name}:`, insertError);
            continue;
          }
          gameTitleId = newGame.id;
        } else {
          gameTitleId = gameTitle.id;
        }

        const achievementsResponse = await fetch(
          `https://api.steampowered.com/ISteamUserStats/GetPlayerAchievements/v1/?key=${apiKey}&steamid=${steamId}&appid=${game.appid}&format=json`
        );

        if (!achievementsResponse.ok) {
          console.error(`Failed to fetch achievements for ${game.name}`);
          continue;
        }

        const achievementsData = await achievementsResponse.json();
        if (!achievementsData.playerstats?.success) {
          console.error(`No achievement data for ${game.name}`);
          continue;
        }

        const playerAchievements = achievementsData.playerstats.achievements || [];

        const globalStats: Record<string, number> = {};
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
          console.log(`Could not fetch global stats for ${game.name}`);
        }

        let earnedCount = 0;
        for (const achievement of playerAchievements) {
          const rarityPercent = globalStats[achievement.apiname] || 0;
          const { data: achievementData, error: achievementError } = await supabase
            .from('achievements')
            .upsert(
              {
                game_title_id: gameTitleId,
                platform: 'steam',
                platform_achievement_id: achievement.apiname,
                name: achievement.name || achievement.apiname,
                description: achievement.description || '',
                icon_url: achievement.icon,
                rarity_global: rarityPercent,
              },
              { onConflict: 'game_title_id,platform,platform_achievement_id', ignoreDuplicates: false }
            )
            .select()
            .single();

          if (achievementError || !achievementData) {
            console.error(`Failed to store achievement ${achievement.name}:`, achievementError);
            continue;
          }

          if (achievement.achieved === 1) {
            earnedCount++;
            await supabase
              .from('user_achievements')
              .upsert(
                {
                  user_id: userId,
                  achievement_id: achievementData.id,
                  platform: 'steam',
                  unlocked_at: achievement.unlocktime
                    ? new Date(achievement.unlocktime * 1000).toISOString()
                    : new Date().toISOString(),
                  platform_unlock_data: { rarity: rarityPercent },
                },
                { onConflict: 'user_id,achievement_id', ignoreDuplicates: false }
              );
          }
        }

        await supabase
          .from('user_games')
          .upsert(
            {
              user_id: userId,
              game_title_id: gameTitleId,
              platform: 'steam',
              steam_achievements_earned: earnedCount,
              steam_total_achievements: playerAchievements.length,
              steam_last_updated_at: new Date().toISOString(),
              last_played_at: game.rtime_last_played
                ? new Date(game.rtime_last_played * 1000).toISOString()
                : null,
            },
            { onConflict: 'user_id,game_title_id,platform', ignoreDuplicates: false }
          );

        processedGames++;
        processedInSession.add(String(game.appid));
      } catch (gameError) {
        console.error(`Error processing game ${game.name}:`, gameError);
        processedInSession.add(String(game.appid));
      }
    }

    const progress =
      gamesWithAchievements.length > 0
        ? Math.min(
            Math.floor((processedInSession.size / gamesWithAchievements.length) * 100),
            100
          )
        : 100;

    await supabase
      .from('steam_sync_logs')
      .update({ games_processed_ids: Array.from(processedInSession) })
      .eq('id', syncLogId);

    if (gamesToSync.length > BATCH_SIZE) {
      await supabase
        .from('profiles')
        .update({ steam_sync_status: 'pending', steam_sync_progress: progress })
        .eq('id', userId);

      await supabase.from('steam_sync_logs').update({ status: 'pending' }).eq('id', syncLogId);
    } else {
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
          games_processed: processedInSession.size,
          achievements_synced: processedGames,
        })
        .eq('id', syncLogId);
    }
  } catch (error) {
    console.error('Steam sync error:', error);

    await supabase
      .from('profiles')
      .update({
        steam_sync_status: 'error',
        steam_sync_error: error instanceof Error ? error.message : 'Unknown error',
      })
      .eq('id', userId);

    await supabase
      .from('steam_sync_logs')
      .update({
        status: 'failed',
        error_message: error instanceof Error ? error.message : 'Unknown error',
      })
      .eq('id', syncLogId);
  }
}