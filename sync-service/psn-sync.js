import { createClient } from '@supabase/supabase-js';
import psnApi from 'psn-api';

const { getUserTitles, getTitleTrophies } = psnApi;

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

export async function syncPSNAchievements(userId, accountId, accessToken, refreshToken, syncLogId) {
  console.log(`Starting PSN sync for user ${userId}`);
  
  try {
    // Set initial status
    await supabase
      .from('profiles')
      .update({ psn_sync_status: 'syncing', psn_sync_progress: 0 })
      .eq('id', userId);

    await supabase
      .from('psn_sync_logs')
      .update({ status: 'syncing' })
      .eq('id', syncLogId);

    // Fetch all games
    const titles = await getUserTitles({ accessToken }, accountId);
    const gamesWithTrophies = titles.trophyTitles.filter(
      title => title.earnedTrophies.bronze > 0 || 
               title.earnedTrophies.silver > 0 || 
               title.earnedTrophies.gold > 0 || 
               title.earnedTrophies.platinum > 0
    );

    console.log(`Found ${gamesWithTrophies.length} games with trophies`);

    let processedGames = 0;
    let totalTrophies = 0;

    // Process all games - NO TIMEOUT!
    for (const title of gamesWithTrophies) {
      try {
        // Upsert game
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

        if (!game) continue;

        // Upsert user_games
        await supabase
          .from('user_games')
          .upsert({
            user_id: userId,
            game_id: game.id,
            platform: 'psn',
            progress: title.progress,
          }, {
            onConflict: 'user_id,game_id',
          });

        // Fetch and sync trophies
        const trophyData = await getTitleTrophies(
          { accessToken },
          title.npCommunicationId,
          'all',
          { npServiceName: title.npServiceName }
        );

        for (const trophy of trophyData.trophies) {
          // Upsert trophy
          const { data: trophyRecord } = await supabase
            .from('trophies')
            .upsert({
              game_id: game.id,
              psn_trophy_id: trophy.trophyId,
              name: trophy.trophyName,
              description: trophy.trophyDetail,
              type: trophy.trophyType,
              icon_url: trophy.trophyIconUrl,
              trophy_group_id: trophy.trophyGroupId,
            }, {
              onConflict: 'game_id,psn_trophy_id',
            })
            .select()
            .single();

          if (!trophyRecord) continue;

          // Upsert user_trophy if earned
          if (trophy.earned) {
            await supabase
              .from('user_trophies')
              .upsert({
                user_id: userId,
                trophy_id: trophyRecord.id,
                earned_at: trophy.earnedDateTime,
              }, {
                onConflict: 'user_id,trophy_id',
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

      } catch (error) {
        console.error(`Error processing title ${title.trophyTitleName}:`, error);
        // Continue with next game
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
