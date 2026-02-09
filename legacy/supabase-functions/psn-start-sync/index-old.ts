/**
 * PSN Start Sync Edge Function
 *
 * Consistent structure with Xbox and Steam implementations for easier
 * maintenance across platforms.
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  exchangeNpssoForCode,
  exchangeCodeForToken,
  getUserTitles,
  getTitleTrophies,
} from 'npm:psn-api@2';

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
      .select('psn_account_id, psn_access_token, psn_refresh_token, psn_sync_status')
      .eq('id', user.id)
      .single();

    if (profileError || !profile) {
      return jsonResponse({ error: 'Profile not found' }, { status: 404 });
    }

    if (!profile.psn_account_id || !profile.psn_access_token) {
      return jsonResponse({ error: 'PSN account not linked' }, { status: 400 });
    }

    if (profile.psn_sync_status === 'syncing') {
      return jsonResponse(
        {
          error: 'Sync already in progress',
          message: 'A sync is already running. Please wait for it to complete.',
        },
        { status: 409 }
      );
    }

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
      throw logError;
    }

    await supabase
      .from('profiles')
      .update({ psn_sync_status: 'pending', psn_sync_progress: 0, psn_sync_error: null })
      .eq('id', user.id);

    syncPSNTrophies(
      user.id,
      profile.psn_account_id,
      profile.psn_access_token,
      profile.psn_refresh_token,
      syncLog.id
    ).catch((error) => console.error('Background sync error:', error));

    return jsonResponse({
      success: true,
      syncLogId: syncLog.id,
      message: 'PSN sync started successfully',
    });
  } catch (error) {
    console.error('Error starting PSN sync:', error);
    return jsonResponse(
      { error: error instanceof Error ? error.message : 'Failed to start PSN sync' },
      { status: 500 }
    );
  }
});

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

  const BATCH_SIZE = 5;
  const authorization = { accessToken, refreshToken };

  try {
    console.log(`PSN sync batch started for user ${userId}, Account ID: ${accountId}`);

    const titlesResponse = await getUserTitles(authorization, accountId);
    const titles = titlesResponse.trophyTitles || [];

    const gamesWithTrophies = titles.filter((title: any) => {
      const earned =
        title.earnedTrophies?.bronze +
          title.earnedTrophies?.silver +
          title.earnedTrophies?.gold +
          title.earnedTrophies?.platinum || 0;
      return earned > 0;
    });

    const { data: processedGamesData } = await supabase
      .from('psn_sync_logs')
      .select('games_processed_ids')
      .eq('id', syncLogId)
      .single();

    const processedInSession = new Set(processedGamesData?.games_processed_ids || []);
    const gamesToSync = gamesWithTrophies.filter((title: any) => {
      return !processedInSession.has(title.npCommunicationId);
    });

    const currentProgress =
      gamesWithTrophies.length > 0
        ? Math.min(
            Math.floor((processedInSession.size / gamesWithTrophies.length) * 100),
            100
          )
        : 0;

    const batchTitles = gamesToSync.slice(0, BATCH_SIZE);
    if (batchTitles.length === 0) {
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
        .update({ status: 'completed', completed_at: new Date().toISOString() })
        .eq('id', syncLogId);
      return;
    }

    await supabase
      .from('profiles')
      .update({ psn_sync_status: 'syncing', psn_sync_progress: currentProgress })
      .eq('id', userId);

    await supabase.from('psn_sync_logs').update({ status: 'syncing' }).eq('id', syncLogId);

    let processedGames = 0;

    for (const title of batchTitles) {
      try {
        let { data: gameTitle } = await supabase
          .from('game_titles')
          .select('id')
          .eq('psn_np_communication_id', title.npCommunicationId)
          .single();

        let gameTitleId: number;
        if (!gameTitle) {
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

        const trophiesResponse = await getTitleTrophies(
          authorization,
          title.npCommunicationId,
          'all',
          { npServiceName: title.npServiceName }
        );

        const trophies = trophiesResponse.trophies || [];
        let earnedCount = 0;

        for (const trophy of trophies) {
          const rarityPercent = trophy.trophyEarnedRate || 0;
          const { data: trophyData, error: trophyError } = await supabase
            .from('achievements')
            .upsert(
              {
                game_title_id: gameTitleId,
                platform: 'playstation',
                platform_achievement_id: String(trophy.trophyId),
                name: trophy.trophyName,
                description: trophy.trophyDetail || '',
                icon_url: trophy.trophyIconUrl,
                rarity_global: rarityPercent,
                psn_trophy_type: trophy.trophyType,
                psn_is_hidden: trophy.trophyHidden || false,
              },
              { onConflict: 'game_title_id,platform,platform_achievement_id', ignoreDuplicates: false }
            )
            .select()
            .single();

          if (trophyError || !trophyData) {
            console.error(`Failed to store trophy ${trophy.trophyName}:`, trophyError);
            continue;
          }

          if (trophy.earned) {
            earnedCount++;
            await supabase
              .from('user_achievements')
              .upsert(
                {
                  user_id: userId,
                  achievement_id: trophyData.id,
                  platform: 'playstation',
                  unlocked_at: trophy.earnedDateTime || new Date().toISOString(),
                  platform_unlock_data: {
                    rarity: rarityPercent,
                    trophyType: trophy.trophyType,
                  },
                },
                { onConflict: 'user_id,achievement_id', ignoreDuplicates: false }
              );
          }
        }

        const totalTrophies =
          title.definedTrophies?.bronze +
            title.definedTrophies?.silver +
            title.definedTrophies?.gold +
            title.definedTrophies?.platinum || 0;
        const earnedTrophies =
          title.earnedTrophies?.bronze +
            title.earnedTrophies?.silver +
            title.earnedTrophies?.gold +
            title.earnedTrophies?.platinum || 0;

        await supabase
          .from('user_games')
          .upsert(
            {
              user_id: userId,
              game_title_id: gameTitleId,
              platform: 'playstation',
              psn_trophies_earned: earnedTrophies,
              psn_total_trophies: totalTrophies,
              psn_trophy_progress: title.progress || 0,
              psn_last_updated_at: new Date().toISOString(),
              last_played_at: title.lastUpdatedDateTime || null,
            },
            { onConflict: 'user_id,game_title_id,platform', ignoreDuplicates: false }
          );

        processedGames++;
        processedInSession.add(title.npCommunicationId);
      } catch (gameError) {
        console.error(`Error processing game ${title.trophyTitleName}:`, gameError);
        processedInSession.add(title.npCommunicationId);
      }
    }

    const progress =
      gamesWithTrophies.length > 0
        ? Math.min(
            Math.floor((processedInSession.size / gamesWithTrophies.length) * 100),
            100
          )
        : 100;

    await supabase
      .from('psn_sync_logs')
      .update({ games_processed_ids: Array.from(processedInSession) })
      .eq('id', syncLogId);

    if (gamesToSync.length > BATCH_SIZE) {
      await supabase
        .from('profiles')
        .update({ psn_sync_status: 'pending', psn_sync_progress: progress })
        .eq('id', userId);

      await supabase.from('psn_sync_logs').update({ status: 'pending' }).eq('id', syncLogId);
    } else {
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