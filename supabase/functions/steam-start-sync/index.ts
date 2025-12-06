/**
 * Steam Start Sync Edge Function
 * 
 * UNIFIED ARCHITECTURE - Matches Xbox and PSN exactly
 * - Creates sync log for session tracking
 * - Processes ALL games (never skips based on DB, only based on THIS session)
 * - Batch of 5 games at a time
 * - Progress 0-100% based on games processed THIS session
 * - Upserts everything (updates existing data)
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

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

    // Get user profile with Steam credentials
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('steam_id, steam_api_key, steam_sync_status')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!profile.steam_id || !profile.steam_api_key) {
      return new Response(JSON.stringify({ error: 'Steam account not linked' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Check if sync is already in progress
    if (profile.steam_sync_status === 'syncing') {
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

    console.log(`Starting Steam sync for user ${user.id}`);

    // Create sync log entry
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
      console.error('Failed to create sync log:', logError);
      throw logError;
    }

    // Update profile sync status
    await supabase
      .from('profiles')
      .update({
        steam_sync_status: 'pending',
        steam_sync_progress: 0,
        steam_sync_error: null,
      })
      .eq('id', user.id);

    // Start background sync process
    syncSteamAchievements(user.id, profile.steam_id, profile.steam_api_key, syncLog.id)
      .catch((error) => {
        console.error('Background sync error:', error);
      });

    return new Response(
      JSON.stringify({
        success: true,
        syncLogId: syncLog.id,
        message: 'Steam sync started successfully',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error starting Steam sync:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to start Steam sync',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

/**
 * Background sync process - IDENTICAL PATTERN TO XBOX
 */
async function syncSteamAchievements(
  userId: string,
  steamId: string,
  apiKey: string,
  syncLogId: number
) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);
  
  const BATCH_SIZE = 5; // Process 5 games per call

  try {
    console.log(`Steam sync batch started for user ${userId}, Steam ID: ${steamId}`);

    // Fetch owned games
    console.log('Fetching Steam games...');
    const gamesResponse = await fetch(
      `https://api.steampowered.com/IPlayerService/GetOwnedGames/v1/?key=${apiKey}&steamid=${steamId}&include_appinfo=1&include_played_free_games=1&format=json`
    );

    if (!gamesResponse.ok) {
      throw new Error(`Failed to fetch Steam games: ${gamesResponse.statusText}`);
    }

    const gamesData = await gamesResponse.json();
    const games = gamesData.response?.games || [];

    console.log(`Found ${games.length} total Steam games`);
    
    // Filter to only games with achievements
    const gamesWithAchievements = games.filter((game: any) => game.has_community_visible_stats);
    
    console.log(`Filtered to ${gamesWithAchievements.length} games with achievements`);

    // Get games already processed in THIS sync session from sync log
    const { data: processedGamesData } = await supabase
      .from('steam_sync_logs')
      .select('games_processed_ids')
      .eq('id', syncLogId)
      .single();

    const processedInSession = new Set(processedGamesData?.games_processed_ids || []);
    console.log(`Already processed in this session: ${processedInSession.size} games`);

    // Filter to games NOT YET PROCESSED in this session only
    // We want to sync ALL games to update rarity/scores/new achievements
    const gamesToSync = gamesWithAchievements.filter((game: any) => {
      return !processedInSession.has(String(game.appid));
    });
    
    console.log(`Remaining games to process this session: ${gamesToSync.length}`);

    // Calculate current progress based on games processed in THIS session
    const currentProgress = gamesWithAchievements.length > 0 
      ? Math.min(Math.floor((processedInSession.size / gamesWithAchievements.length) * 100), 100) 
      : 0;

    // Take next batch
    const batchGames = gamesToSync.slice(0, BATCH_SIZE);

    if (batchGames.length === 0) {
      // All games synced - complete
      console.log('All games already synced!');
      
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
        })
        .eq('id', syncLogId);

      return;
    }

    console.log(`Processing batch of ${batchGames.length} games... (Current progress: ${currentProgress}%)`);

    // Update status to syncing with current progress
    await supabase
      .from('profiles')
      .update({ 
        steam_sync_status: 'syncing',
        steam_sync_progress: currentProgress,
      })
      .eq('id', userId);

    await supabase
      .from('steam_sync_logs')
      .update({ status: 'syncing' })
      .eq('id', syncLogId);

    let processedGames = 0;

    for (const game of batchGames) {
      try {
        console.log(`Processing: ${game.name} (App ID: ${game.appid})`);

        // Check if game exists in game_titles
        let { data: gameTitle } = await supabase
          .from('game_titles')
          .select('id')
          .eq('steam_app_id', game.appid)
          .single();

        let gameTitleId: number;

        if (!gameTitle) {
          // Create new game title
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

        // Fetch player achievements
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

        // Fetch global achievement percentages
        let globalStats: any = {};
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

        // Process each achievement
        let earnedCount = 0;
        for (const achievement of playerAchievements) {
          const rarityPercent = globalStats[achievement.apiname] || 0;

          // Upsert achievement
          const { data: achievementData, error: achievementError } = await supabase
            .from('achievements')
            .upsert({
              game_title_id: gameTitleId,
              platform: 'steam',
              platform_achievement_id: achievement.apiname,
              name: achievement.name || achievement.apiname,
              description: achievement.description || '',
              icon_url: achievement.icon,
              rarity_global: rarityPercent,
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
            continue;
          }

          // Store user achievement if unlocked
          if (achievement.achieved === 1) {
            earnedCount++;
            await supabase
              .from('user_achievements')
              .upsert({
                user_id: userId,
                achievement_id: achievementData.id,
                platform: 'steam',
                unlocked_at: achievement.unlocktime 
                  ? new Date(achievement.unlocktime * 1000).toISOString()
                  : new Date().toISOString(),
                platform_unlock_data: {
                  rarity: rarityPercent,
                },
              }, {
                onConflict: 'user_id,achievement_id',
                ignoreDuplicates: false,
              });
          }
        }

        // Upsert user_games entry
        await supabase
          .from('user_games')
          .upsert({
            user_id: userId,
            game_title_id: gameTitleId,
            platform: 'steam',
            steam_achievements_earned: earnedCount,
            steam_total_achievements: playerAchievements.length,
            steam_last_updated_at: new Date().toISOString(),
            last_played_at: game.rtime_last_played 
              ? new Date(game.rtime_last_played * 1000).toISOString()
              : null,
          }, {
            onConflict: 'user_id,game_title_id,platform',
            ignoreDuplicates: false,
          });

        processedGames++;
        // Track this game as processed in this session
        processedInSession.add(String(game.appid));

      } catch (gameError) {
        console.error(`Error processing game ${game.name}:`, gameError);
      }
    }

    // Calculate progress based on games processed in THIS session
    const progress = gamesWithAchievements.length > 0 
      ? Math.min(Math.floor((processedInSession.size / gamesWithAchievements.length) * 100), 100) 
      : 100;

    console.log(`Batch complete: ${processedGames} games processed. Total progress: ${processedInSession.size}/${gamesWithAchievements.length} (${progress}%)`);

    // Update sync log with processed games
    await supabase
      .from('steam_sync_logs')
      .update({ 
        games_processed_ids: Array.from(processedInSession),
      })
      .eq('id', syncLogId);

    // Check if more games remain
    if (gamesToSync.length > BATCH_SIZE) {
      // More games to process - mark as pending for auto-resume
      console.log(`${gamesToSync.length - BATCH_SIZE} games remaining - status set to pending for next batch`);
      
      await supabase
        .from('profiles')
        .update({
          steam_sync_status: 'pending',
          steam_sync_progress: progress,
        })
        .eq('id', userId);

      await supabase
        .from('steam_sync_logs')
        .update({ status: 'pending' })
        .eq('id', syncLogId);
    } else {
      // All games synced - complete
      console.log('All games synced successfully!');
      
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
