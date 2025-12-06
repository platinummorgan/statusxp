/**
 * Bulk Update Trophy Rarity Edge Function
 * 
 * Fetches rarity for ALL trophies in the database directly from PSN API
 * and updates them in one go. No batch processing bullshit.
 */

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  exchangeRefreshTokenForAuthTokens,
  getUserTrophiesEarnedForTitle,
  getUserTrophyGroupEarningsForTitle,
} from '../_shared/psn-api.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json().catch(() => ({}));
    const batchSize = body.batchSize || 50;
    const offset = body.offset || 0;
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: req.headers.get('Authorization')! },
        },
      }
    );

    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Get user's PSN credentials
    const { data: profile } = await supabase
      .from('profiles')
      .select('psn_account_id, psn_refresh_token')
      .eq('id', user.id)
      .single();

    if (!profile?.psn_refresh_token) {
      return new Response(JSON.stringify({ error: 'PSN not linked' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Get fresh access token
    console.log('Getting fresh PSN access token...');
    const authTokens = await exchangeRefreshTokenForAuthTokens(profile.psn_refresh_token);
    console.log('Got access token, length:', authTokens.accessToken?.length);
    
    const authorization = {
      accessToken: authTokens.accessToken,
    };

    // First, get the user's game title IDs
    console.log('Fetching user games for user:', user.id);
    const { data: userGames, error: userGamesError } = await supabase
      .from('user_games')
      .select('game_title_id')
      .eq('user_id', user.id);

    if (userGamesError) {
      console.error('Error fetching user games:', userGamesError);
      throw userGamesError;
    }

    console.log('Found user_games:', userGames?.length);

    if (!userGames || userGames.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          totalUpdated: 0,
          message: 'No games found for user',
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const gameTitleIds = userGames.map((g: any) => g.game_title_id);
    console.log(`Found ${gameTitleIds.length} game title IDs`);

    // Now get the game titles with PSN data
    console.log('Fetching game_titles...');
    const { data: gameTitles, error: gamesError } = await supabase
      .from('game_titles')
      .select('id, psn_np_communication_id, psn_np_service_name')
      .in('id', gameTitleIds);

    if (gamesError) {
      console.error('Error fetching game titles:', gamesError);
      throw gamesError;
    }

    console.log(`Got ${gameTitles?.length || 0} game titles total`);
    
    // Filter to only games with PSN data
    const gamesWithPSN = gameTitles?.filter((g: any) => g.psn_np_communication_id != null) || [];
    console.log(`Total games with PSN data: ${gamesWithPSN.length}`);
    
    // Find games that are missing rarity data (platinum trophies without rarity_global)
    const { data: missingRarityData } = await supabase
      .from('trophies')
      .select('game_title_id')
      .eq('tier', 'platinum')
      .is('rarity_global', null)
      .in('game_title_id', gamesWithPSN.map((g: any) => g.id));
    
    const gameIdsNeedingRarity = new Set(
      (missingRarityData || []).map((row: any) => row.game_title_id)
    );
    
    // Only process games that actually need rarity data
    const gamesNeedingUpdate = gamesWithPSN.filter((g: any) => 
      gameIdsNeedingRarity.has(g.id)
    );
    
    console.log(`Games needing rarity update: ${gamesNeedingUpdate.length} out of ${gamesWithPSN.length}`);
    
    // Apply batching
    const gamesToProcess = gamesNeedingUpdate.slice(offset, offset + batchSize);
    const hasMore = offset + batchSize < gamesNeedingUpdate.length;
    
    console.log(`Processing batch: ${offset} to ${offset + gamesToProcess.length} of ${gamesNeedingUpdate.length}`);

    if (gamesToProcess.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          totalUpdated: 0,
          message: 'No games with PSN data found',
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    let totalUpdated = 0;

    // Process each game in this batch
    for (const gameTitle of gamesToProcess) {
      try {
        console.log(`Processing game ${gameTitle.id}: ${gameTitle.psn_np_communication_id}`);
        
        // Get trophy groups for this title
        const groupsData = await getUserTrophyGroupEarningsForTitle(
          authorization,
          profile.psn_account_id,
          gameTitle.psn_np_communication_id,
          { npServiceName: gameTitle.psn_np_service_name || 'trophy' }
        );

        console.log(`  Found ${groupsData.trophyGroups.length} trophy groups`);

        // Determine which trophy groups to fetch
        const trophyGroupsToFetch = groupsData.trophyGroups.map((g: any) => g.trophyGroupId);

        // Fetch trophies and rarity for ALL trophy groups (base + DLC)
        for (const groupId of trophyGroupsToFetch) {
          console.log(`  Fetching group ${groupId}...`);
          
          // Fetch ALL trophies with earned status and rarity for this group
          const earnedData = await getUserTrophiesEarnedForTitle(
            authorization,
            profile.psn_account_id,
            gameTitle.psn_np_communication_id,
            groupId,
            { npServiceName: gameTitle.psn_np_service_name || 'trophy' }
          );

          console.log(`    Got ${earnedData.trophies.length} trophies`);

          // Update each trophy's rarity
          for (const earnedTrophy of earnedData.trophies) {
            if (earnedTrophy.trophyEarnedRate) {
              const { error } = await supabase
                .from('trophies')
                .update({
                  rarity_global: parseFloat(earnedTrophy.trophyEarnedRate),
                  psn_earn_rate: parseFloat(earnedTrophy.trophyEarnedRate),
                })
                .eq('game_title_id', gameTitle.id)
                .eq('psn_trophy_id', earnedTrophy.trophyId);

              if (!error) {
                totalUpdated++;
              }
            }
          }

          console.log(`  ✓ Updated trophies for group ${groupId}`);
        }

      } catch (error) {
        console.error(`ERROR processing game ${gameTitle.id}:`, error);
        console.error(`Error message:`, error instanceof Error ? error.message : String(error));
        // Continue with next game
      }
    }

    console.log(`Batch complete. Total trophies updated in this batch: ${totalUpdated}`);

    return new Response(
      JSON.stringify({
        success: true,
        totalUpdated,
        batchProcessed: gamesToProcess.length,
        totalGames: gamesNeedingUpdate.length,
        offset,
        hasMore,
        nextOffset: hasMore ? offset + batchSize : null,
        message: `Updated ${totalUpdated} trophies across ${gamesToProcess.length} games (${offset + gamesToProcess.length}/${gamesNeedingUpdate.length})`,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );

  } catch (error) {
    console.error('ERROR in bulk-update-rarity:');
    console.error('Error object:', error);
    console.error('Error type:', typeof error);
    console.error('Error message:', error instanceof Error ? error.message : String(error));
    console.error('Error stack:', error instanceof Error ? error.stack : 'No stack trace');
    
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : String(error),
        details: error instanceof Error ? error.stack : undefined,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
