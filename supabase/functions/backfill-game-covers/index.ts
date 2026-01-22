// Backfill game covers by downloading external URLs and uploading to Supabase Storage
// This fixes CORS issues on web for PlayStation and Xbox game covers

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface Game {
  platform_id: number;
  platform_game_id: string;
  cover_url: string;
}

async function downloadAndUploadCover(
  game: Game,
  supabase: any
): Promise<string | null> {
  try {
    console.log(`Processing ${game.platform_game_id} on platform ${game.platform_id}`);
    
    // Download the image from the external URL
    const response = await fetch(game.cover_url);
    if (!response.ok) {
      console.error(`Failed to download cover: ${response.statusText}`);
      return null;
    }

    // Get the image data as a blob
    const blob = await response.blob();
    const arrayBuffer = await blob.arrayBuffer();
    const contentType = response.headers.get('content-type') || 'image/jpeg';

    // Generate file path: game-covers/{platform_id}/{platform_game_id}.jpg
    const extension = contentType.includes('png') ? 'png' : 'jpg';
    const filePath = `game-covers/${game.platform_id}/${game.platform_game_id}.${extension}`;

    // Upload to Supabase Storage
    const { data: uploadData, error: uploadError } = await supabase
      .storage
      .from('game-covers')
      .upload(filePath, arrayBuffer, {
        contentType,
        upsert: true, // Overwrite if exists
      });

    if (uploadError) {
      console.error(`Upload error: ${uploadError.message}`);
      return null;
    }

    // Get public URL
    const { data: urlData } = supabase
      .storage
      .from('game-covers')
      .getPublicUrl(filePath);

    console.log(`Uploaded successfully: ${urlData.publicUrl}`);
    return urlData.publicUrl;
  } catch (error) {
    console.error(`Error processing game cover:`, error);
    return null;
  }
}

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const { platform_ids, batch_size = 50, offset = 0 } = await req.json();

    if (!platform_ids || !Array.isArray(platform_ids)) {
      return new Response(
        JSON.stringify({ error: 'platform_ids array required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      );
    }

    // Fetch games that need backfilling (external URLs only)
    const { data: games, error: fetchError } = await supabase
      .from('games')
      .select('platform_id, platform_game_id, cover_url')
      .in('platform_id', platform_ids)
      .not('cover_url', 'is', null)
      .not('cover_url', 'like', '%supabase%')
      .not('cover_url', 'like', '%cloudfront%')
      .range(offset, offset + batch_size - 1);

    if (fetchError) {
      throw fetchError;
    }

    console.log(`Found ${games?.length || 0} games to process`);

    const results = {
      total: games?.length || 0,
      success: 0,
      failed: 0,
      processed: [] as any[],
    };

    // Process each game
    for (const game of games || []) {
      const newUrl = await downloadAndUploadCover(game, supabase);
      
      if (newUrl) {
        // Update the database with the new URL
        const { error: updateError } = await supabase
          .from('games')
          .update({ cover_url: newUrl })
          .eq('platform_id', game.platform_id)
          .eq('platform_game_id', game.platform_game_id);

        if (updateError) {
          console.error(`Failed to update DB for ${game.platform_game_id}:`, updateError);
          results.failed++;
        } else {
          results.success++;
          results.processed.push({
            platform_id: game.platform_id,
            platform_game_id: game.platform_game_id,
            new_url: newUrl,
          });
        }
      } else {
        results.failed++;
      }
    }

    return new Response(
      JSON.stringify(results),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
