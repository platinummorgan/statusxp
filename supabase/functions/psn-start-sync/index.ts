/**
 * PSN Start Sync Edge Function
 * 
 * UNIFIED ARCHITECTURE - Matches Xbox and Steam exactly
 * - Creates sync log for session tracking
 * - Processes ALL games (never skips based on DB, only based on THIS session)
 * - Batch of 5 games at a time
 * - Progress 0-100% based on games processed THIS session
 * - Upserts everything (updates existing data)
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { exchangeNpssoForCode, exchangeCodeForToken, getUserTitles, getTitleTrophies } from 'npm:psn-api@2';

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

    // Get user profile with PSN credentials
    const { data: profile, error: profileError } = await supabase
      .from('profiles')
      .select('psn_account_id, psn_access_token, psn_refresh_token, psn_sync_status')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      return new Response(JSON.stringify({ error: 'Profile not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    if (!profile.psn_account_id || !profile.psn_access_token) {
      return new Response(JSON.stringify({ error: 'PSN account not linked' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Check if sync is already in progress
    if (profile.psn_sync_status === 'syncing') {
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

    console.log(`Starting PSN sync for user ${user.id}`);

    // Create sync log entry
    const { data: syncLog, error: logError } = await supabase
      .from('psn_sync_logs')
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
        psn_sync_status: 'pending',
        psn_sync_progress: 0,
        psn_sync_error: null,
      })
      .eq('id', user.id);

    // Start background sync process
    syncPSNTrophies(
      user.id, 
      profile.psn_account_id, 
      profile.psn_access_token,
      profile.psn_refresh_token,
      syncLog.id
    ).catch((error) => {
      console.error('Background sync error:', error);
    });

    return new Response(
      JSON.stringify({
        success: true,
        syncLogId: syncLog.id,
        message: 'PSN sync started successfully',
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error starting PSN sync:', error);
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : 'Failed to start PSN sync',
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});

/**
 * Background sync process - IDENTICAL PATTERN TO XBOX AND STEAM
 */
async function syncPSNTrophies(
  userId: string,
  accountId: string,
  accessToken: string,
  refreshToken: string,
  syncLogId: number
) {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, supabaseServiceKey);
  
  const BATCH_SIZE = 5; // Process 5 games per call

  const authorization = {
    accessToken: accessToken,
    refreshToken: refreshToken,
  };

  try {
    console.log(`PSN sync batch started for user ${userId}, Account ID: ${accountId}`);

    // Fetch user titles
    console.log('Fetching PSN titles...');
    const titlesResponse = await getUserTitles(authorization, accountId);
    const titles = titlesResponse.trophyTitles || [];

    console.log(`Found ${titles.length} total PSN games`);
    
    // Filter to only games with trophies
    const gamesWithTrophies = titles.filter((title: any) => {
      const earned = title.earnedTrophies?.bronze + title.earnedTrophies?.silver + title.earnedTrophies?.gold + title.earnedTrophies?.platinum || 0;
      return earned > 0;
    });
    
    console.log(`Filtered to ${gamesWithTrophies.length} games with earned trophies`);

    // Get games already processed in THIS sync session from sync log
    const { data: processedGamesData } = await supabase
      .from('psn_sync_logs')
      .select('games_processed_ids')
      .eq('id', syncLogId)
      .single();

    const processedInSession = new Set(processedGamesData?.games_processed_ids || []);
    console.log(`Already processed in this session: ${processedInSession.size} games`);

    // Filter to games NOT YET PROCESSED in this session only
    const gamesToSync = gamesWithTrophies.filter((title: any) => {
      return !processedInSession.has(title.npCommunicationId);
    });
    
    console.log(`Remaining games to process this session: ${gamesToSync.length}`);

    // Calculate current progress based on games processed in THIS session
    const currentProgress = gamesWithTrophies.length > 0 
      ? Math.min(Math.floor((processedInSession.size / gamesWithTrophies.length) * 100), 100) 
      : 0;

    // Take next batch
    const batchTitles = gamesToSync.slice(0, BATCH_SIZE);

    if (batchTitles.length === 0) {
      // All games synced - complete
      console.log('All games already synced!');
      
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
        })
        .eq('id', syncLogId);

      return;
    }

    console.log(`Processing batch of ${batchTitles.length} games... (Current progress: ${currentProgress}%)`);

    // Update status to syncing with current progress
    await supabase
      .from('profiles')
      .update({ 
        psn_sync_status: 'syncing',
        psn_sync_progress: currentProgress,
      })
      .eq('id', userId);

    await supabase
      .from('psn_sync_logs')
      .update({ status: 'syncing' })
      .eq('id', syncLogId);

    let processedGames = 0;

    for (const title of batchTitles) {
      try {
        console.log(`Processing: ${title.trophyTitleName} (${title.npCommunicationId})`);

        // Check if game exists in game_titles
        let { data: gameTitle } = await supabase
          .from('game_titles')
          .select('id')
          .eq('psn_np_communication_id', title.npCommunicationId)
          .single();

        let gameTitleId: number;

        if (!gameTitle) {
          // Create new game title
          const { data: newGame, error: insertError } = await supabase
            .from('game_titles')
            .insert({
              name: title.trophyTitleName,
              platform: 'playstation',
              psn_np_communication_id: title.npCommunicationId,
              cover_url: title.trophyTitleIconUrl,
            })
            .select('id')
            .single();

          if (insertError) {
            console.error(`Failed to create game title for ${title.trophyTitleName}:`, insertError);
            continue;
          }

          gameTitleId = newGame.id;
        } else {
          gameTitleId = gameTitle.id;
        }

        // Fetch trophies for this title
        const trophiesResponse = await getTitleTrophies(
          authorization,
          title.npCommunicationId,
          'all',
          { npServiceName: title.npServiceName }
        );

        const trophies = trophiesResponse.trophies || [];
        console.log(`Processing ${trophies.length} trophies for ${title.trophyTitleName}`);

        // Process each trophy
        let earnedCount = 0;
        for (const trophy of trophies) {
          const rarityPercent = trophy.trophyEarnedRate || 0;

          // Upsert trophy (achievement)
          const { data: trophyData, error: trophyError } = await supabase
            .from('achievements')
            .upsert({
              game_title_id: gameTitleId,
              platform: 'playstation',
              platform_achievement_id: String(trophy.trophyId),
              name: trophy.trophyName,
              description: trophy.trophyDetail || '',
              icon_url: trophy.trophyIconUrl,
              rarity_global: rarityPercent,
              psn_trophy_type: trophy.trophyType,
              psn_is_hidden: trophy.trophyHidden || false,
            }, {
              onConflict: 'game_title_id,platform,platform_achievement_id',
              ignoreDuplicates: false,
            })
            .select()
            .single();

          if (trophyError) {
            console.error(`Failed to store trophy ${trophy.trophyName}:`, trophyError);
            continue;
          }

          if (!trophyData) {
            continue;
          }

          // Store user trophy if earned
          if (trophy.earned) {
            earnedCount++;
            await supabase
              .from('user_achievements')
              .upsert({
                user_id: userId,
                achievement_id: trophyData.id,
                platform: 'playstation',
                unlocked_at: trophy.earnedDateTime || new Date().toISOString(),
                platform_unlock_data: {
                  rarity: rarityPercent,
                  trophyType: trophy.trophyType,
                },
              }, {
                onConflict: 'user_id,achievement_id',
                ignoreDuplicates: false,
              });
          }
        }

        // Upsert user_games entry
        const totalTrophies = title.definedTrophies?.bronze + title.definedTrophies?.silver + 
                            title.definedTrophies?.gold + title.definedTrophies?.platinum || 0;
        const earnedTrophies = title.earnedTrophies?.bronze + title.earnedTrophies?.silver + 
                             title.earnedTrophies?.gold + title.earnedTrophies?.platinum || 0;

        await supabase
          .from('user_games')
          .upsert({
            user_id: userId,
            game_title_id: gameTitleId,
            platform: 'playstation',
            psn_trophies_earned: earnedTrophies,
            psn_total_trophies: totalTrophies,
            psn_trophy_progress: title.progress || 0,
            psn_last_updated_at: new Date().toISOString(),
            last_played_at: title.lastUpdatedDateTime || null,
          }, {
            onConflict: 'user_id,game_title_id,platform',
            ignoreDuplicates: false,
          });

        processedGames++;
        // Track this game as processed in this session
        processedInSession.add(title.npCommunicationId);

      } catch (gameError) {
        console.error(`Error processing game ${title.trophyTitleName}:`, gameError);
      }
    }

    // Calculate progress based on games processed in THIS session
    const progress = gamesWithTrophies.length > 0 
      ? Math.min(Math.floor((processedInSession.size / gamesWithTrophies.length) * 100), 100) 
      : 100;

    console.log(`Batch complete: ${processedGames} games processed. Total progress: ${processedInSession.size}/${gamesWithTrophies.length} (${progress}%)`);

    // Update sync log with processed games
    await supabase
      .from('psn_sync_logs')
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
          psn_sync_status: 'pending',
          psn_sync_progress: progress,
        })
        .eq('id', userId);

      await supabase
        .from('psn_sync_logs')
        .update({ status: 'pending' })
        .eq('id', syncLogId);
    } else {
      // All games synced - complete
      console.log('All games synced successfully!');
      
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
          games_processed: processedInSession.size,
          trophies_synced: processedGames,
        })
        .eq('id', syncLogId);
    }

  } catch (error) {
    console.error('PSN sync error:', error);
    
    await supabase
      .from('profiles')
      .update({
        psn_sync_status: 'error',
        psn_sync_error: error instanceof Error ? error.message : 'Unknown error',
      })
      .eq('id', userId);

    await supabase
      .from('psn_sync_logs')
      .update({ 
        status: 'failed',
        error_message: error instanceof Error ? error.message : 'Unknown error',
      })
      .eq('id', syncLogId);
  }
}
