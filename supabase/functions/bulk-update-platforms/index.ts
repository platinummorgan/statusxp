/**
 * Bulk Update Platform IDs
 * 
 * Updates platform_id for all user_games by reading from their game_titles
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
    const body = await req.json().catch(() => ({}));
    const batchSize = body.batchSize || 100;
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

    console.log(`Processing batch: offset=${offset}, batchSize=${batchSize}`);

    // Get user_games that need platform_id updates (where platform_id is null)
    // Join with game_titles to get the platform_id
    const { data: userGames, error: fetchError } = await supabase
      .from('user_games')
      .select(`
        id,
        game_title_id,
        platform_id,
        game_titles!inner(
          id,
          name,
          platform_id
        )
      `)
      .eq('user_id', user.id)
      .is('platform_id', null)
      .range(offset, offset + batchSize - 1);

    if (fetchError) {
      console.error('Error fetching user games:', fetchError);
      throw fetchError;
    }

    console.log(`Found ${userGames?.length || 0} games to update in this batch`);

    if (!userGames || userGames.length === 0) {
      return new Response(
        JSON.stringify({
          success: true,
          updated: 0,
          hasMore: false,
          nextOffset: offset,
          message: 'No more games to update',
        }),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    // Update each user_game with the platform_id from its game_title
    let updated = 0;
    for (const userGame of userGames) {
      const gameTitle = userGame.game_titles as any;
      
      if (gameTitle && gameTitle.platform_id) {
        const { error: updateError } = await supabase
          .from('user_games')
          .update({ platform_id: gameTitle.platform_id })
          .eq('id', userGame.id);

        if (updateError) {
          console.error(`Error updating user_game ${userGame.id}:`, updateError);
        } else {
          updated++;
          console.log(`Updated ${gameTitle.name}: platform_id = ${gameTitle.platform_id}`);
        }
      }
    }

    const hasMore = userGames.length === batchSize;
    const nextOffset = offset + batchSize;

    console.log(`Batch complete: updated ${updated}/${userGames.length}, hasMore=${hasMore}`);

    return new Response(
      JSON.stringify({
        success: true,
        updated,
        hasMore,
        nextOffset: hasMore ? nextOffset : offset,
        message: `Updated ${updated} games`,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('ERROR in bulk-update-platforms:', error);
    return new Response(
      JSON.stringify({
        error: error.message,
        details: error.toString(),
      }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
