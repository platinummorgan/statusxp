import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export async function syncSteamAchievements(userId, steamId, apiKey, syncLogId) {
  console.log(`Starting Steam sync for user ${userId}`);
  
  try {
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

    let processedGames = 0;
    let totalAchievements = 0;

    // Process all games - NO TIMEOUT!
    for (const game of ownedGames) {
      try {
        console.log(`Processing Steam app ${game.appid} - ${game.name}`);
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

        // Upsert game
        const { data: gameRecord } = await supabase
          .from('games')
          .upsert({
            steam_app_id: game.appid.toString(),
            title: game.name,
            platform: 'steam',
            image_url: `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`,
          }, {
            onConflict: 'steam_app_id',
          })
          .select()
          .single();

        if (!gameRecord) continue;

        // Calculate progress
        const unlockedCount = playerAchievements.filter(a => a.achieved === 1).length;
        const progress = achievements.length > 0 ? (unlockedCount / achievements.length) * 100 : 0;

        // Upsert user_games
        await supabase
          .from('user_games')
          .upsert({
            user_id: userId,
            game_id: gameRecord.id,
            platform: 'steam',
            playtime_minutes: game.playtime_forever || 0,
            achievements_unlocked: unlockedCount,
            total_achievements: achievements.length,
            progress,
          }, {
            onConflict: 'user_id,game_id',
          });

        // Process achievements
        for (let i = 0; i < achievements.length; i++) {
          const achievement = achievements[i];
          const playerAchievement = playerAchievements.find(a => a.apiname === achievement.name);

          // Upsert achievement
          const { data: achievementRecord } = await supabase
            .from('achievements')
            .upsert({
              game_id: gameRecord.id,
              steam_api_name: achievement.name,
              name: achievement.displayName || achievement.name,
              description: achievement.description || '',
              icon_locked_url: achievement.icon || '',
              icon_unlocked_url: achievement.icongray || achievement.icon || '',
            }, {
              onConflict: 'game_id,steam_api_name',
            })
            .select()
            .single();

          if (!achievementRecord) continue;

          // Upsert user_achievement if unlocked
          if (playerAchievement && playerAchievement.achieved === 1) {
            await supabase
              .from('user_achievements')
              .upsert({
                user_id: userId,
                achievement_id: achievementRecord.id,
                unlocked_at: new Date(playerAchievement.unlocktime * 1000).toISOString(),
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

      } catch (error) {
        console.error(`Error processing game ${game.name}:`, error);
        // Continue with next game
      }
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
