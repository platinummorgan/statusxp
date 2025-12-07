import express from 'express';
import cors from 'cors';
import { createClient } from '@supabase/supabase-js';

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Initialize Supabase client
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Health check
app.get('/', (req, res) => {
  res.json({ status: 'ok', service: 'StatusXP Sync Service' });
});

// Xbox sync endpoint - NO TIMEOUT LIMITS!
app.post('/sync/xbox', async (req, res) => {
  const { userId, xuid, userHash, accessToken, syncLogId } = req.body;

  // Respond immediately so the client doesn't wait
  res.json({ success: true, message: 'Xbox sync started in background' });

  // Run sync in background - will complete no matter how long it takes
  syncXboxAchievements(userId, xuid, userHash, accessToken, syncLogId).catch(err => {
    console.error('Xbox sync error:', err);
  });
});

async function syncXboxAchievements(userId, xuid, userHash, accessToken, syncLogId) {
  try {
    console.log(`Starting Xbox sync for user ${userId}`);

    // Set initial status
    await supabase
      .from('profiles')
      .update({ xbox_sync_status: 'syncing', xbox_sync_progress: 0 })
      .eq('id', userId);

    await supabase
      .from('xbox_sync_logs')
      .update({ status: 'syncing' })
      .eq('id', syncLogId);

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

    if (!titleHistoryResponse.ok) {
      throw new Error(`Failed to fetch title history: ${titleHistoryResponse.statusText}`);
    }

    const titleHistory = await titleHistoryResponse.json();
    const titles = titleHistory.titles || [];

    const gamesWithProgress = titles.filter(title => {
      const currentAchievements = title.achievement?.currentAchievements || 0;
      return currentAchievements > 0;
    });

    console.log(`Found ${gamesWithProgress.length} games to sync`);

    let processedCount = 0;
    let totalAchievements = 0;

    // Process ALL games - no batching, no timeout restrictions!
    for (const title of gamesWithProgress) {
      try {
        // Get or create game title
        let gameTitleId;
        const { data: gameTitle } = await supabase
          .from('game_titles')
          .select('id')
          .eq('xbox_title_id', title.titleId)
          .single();

        if (gameTitle) {
          gameTitleId = gameTitle.id;
        } else {
          const { data: newGame } = await supabase
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
          gameTitleId = newGame.id;
        }

        // Fetch achievements for this game
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

        // Fetch global stats
        const globalStatsMap = new Map();
        try {
          const statsResponse = await fetch(
            `https://titlehub.xboxlive.com/titles/${title.titleId}/achievement/stats`,
            {
              headers: {
                'x-xbl-contract-version': '2',
                Authorization: `XBL3.0 x=${userHash};${accessToken}`,
              },
            }
          );
          if (statsResponse.ok) {
            const statsData = await statsResponse.json();
            (statsData.achievements || []).forEach(stat => {
              globalStatsMap.set(stat.id, stat.percentUnlocked || 0);
            });
          }
        } catch (e) {
          console.log(`Could not fetch stats for ${title.name}`);
        }

        // Process all achievements
        for (const achievement of achievements) {
          const rarityPercent = globalStatsMap.get(achievement.id) || 0;

          const { data: achievementData } = await supabase
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

          if (achievementData) {
            totalAchievements++;

            if (achievement.progressState === 'Achieved') {
              await supabase.from('user_achievements').upsert(
                {
                  user_id: userId,
                  achievement_id: achievementData.id,
                  platform: 'xbox',
                  unlocked_at: achievement.progression?.timeUnlocked || new Date().toISOString(),
                  platform_unlock_data: {
                    gamerscore: achievement.rewards?.[0]?.value || 0,
                    rarity: rarityPercent,
                  },
                },
                { onConflict: 'user_id,achievement_id', ignoreDuplicates: false }
              );
            }
          }
        }

        // Update game totals
        await supabase
          .from('game_titles')
          .update({
            xbox_total_achievements: achievements.length,
            xbox_max_gamerscore: title.achievement?.totalGamerscore || 0,
          })
          .eq('id', gameTitleId);

        // Update user game
        const currentAchievements = title.achievement?.currentAchievements || 0;
        const currentGamerscore = title.achievement?.currentGamerscore || 0;
        const totalGamerscore = title.achievement?.totalGamerscore || 0;
        const completionPercent =
          achievements.length > 0
            ? Math.floor((currentAchievements / achievements.length) * 100)
            : 0;

        await supabase.from('user_games').upsert(
          {
            user_id: userId,
            game_title_id: gameTitleId,
            platform: 'xbox',
            total_trophies: achievements.length,
            earned_trophies: currentAchievements,
            completion_percent: completionPercent,
            xbox_current_gamerscore: currentGamerscore,
            xbox_max_gamerscore: totalGamerscore,
            xbox_achievements_earned: currentAchievements,
            xbox_total_achievements: achievements.length,
            xbox_last_updated_at: new Date().toISOString(),
            last_played_at: title.lastUnlock || null,
          },
          { onConflict: 'user_id,game_title_id,platform', ignoreDuplicates: false }
        );

        processedCount++;
        const progress = Math.floor((processedCount / gamesWithProgress.length) * 100);

        // Update progress
        await supabase
          .from('profiles')
          .update({ xbox_sync_progress: progress })
          .eq('id', userId);

        console.log(`Processed ${processedCount}/${gamesWithProgress.length} games (${progress}%)`);
      } catch (gameError) {
        console.error(`Error processing game ${title.name}:`, gameError);
      }
    }

    // Mark as completed
    await supabase
      .from('profiles')
      .update({
        xbox_sync_status: 'completed',
        xbox_sync_progress: 100,
        last_xbox_sync_at: new Date().toISOString(),
      })
      .eq('id', userId);

    await supabase
      .from('xbox_sync_logs')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        games_processed: processedCount,
        achievements_synced: totalAchievements,
      })
      .eq('id', syncLogId);

    console.log(`Xbox sync completed! Processed ${processedCount} games, ${totalAchievements} achievements`);
  } catch (error) {
    console.error('Xbox sync failed:', error);

    await supabase
      .from('profiles')
      .update({
        xbox_sync_status: 'error',
        xbox_sync_error: error.message || 'Unknown error',
      })
      .eq('id', userId);

    await supabase
      .from('xbox_sync_logs')
      .update({
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: error.message || 'Unknown error',
      })
      .eq('id', syncLogId);
  }
}

app.listen(PORT, () => {
  console.log(`Sync service running on port ${PORT}`);
});
