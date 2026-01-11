/**
 * Migration script to copy existing game cover URLs to Supabase Storage
 * This fixes CORS issues when displaying game covers on the web
 */

import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Helper to download external cover and upload to Supabase Storage
async function uploadExternalCover(externalUrl, gameId) {
  try {
    console.log(`[GAME ${gameId}] Downloading cover from:`, externalUrl.substring(0, 80) + '...');
    
    // Download the image from the external URL
    const response = await fetch(externalUrl);
    if (!response.ok) {
      console.error(`  ❌ Failed to download: ${response.status}`);
      return null;
    }

    // Get the image data as a buffer
    const arrayBuffer = await response.arrayBuffer();
    
    // Determine file extension from content type
    const contentType = response.headers.get('content-type') || 'image/jpeg';
    let extension = 'jpg';
    if (contentType.includes('png')) extension = 'png';
    else if (contentType.includes('gif')) extension = 'gif';
    else if (contentType.includes('webp')) extension = 'webp';
    
    // Create a unique filename: covers/gameId_timestamp.ext
    const timestamp = Date.now();
    const filename = `covers/${gameId}_${timestamp}.${extension}`;
    
    console.log(`  ⬆️  Uploading to: ${filename}`);
    
    // Upload to Supabase Storage
    const { data, error } = await supabase.storage
      .from('avatars') // Using same bucket as avatars
      .upload(filename, arrayBuffer, {
        contentType,
        upsert: true,
      });

    if (error) {
      console.error('  ❌ Upload error:', error);
      return null;
    }

    // Get the public URL
    const { data: { publicUrl } } = supabase.storage
      .from('avatars')
      .getPublicUrl(filename);

    console.log(`  ✅ Success: ${publicUrl.substring(0, 80)}...`);
    return publicUrl;
  } catch (error) {
    console.error(`  ❌ Exception:`, error.message);
    return null;
  }
}

async function migrateGameCovers() {
  console.log('🚀 Starting game cover migration...\n');

  // Get all game titles with cover URLs that haven't been proxied yet
  const { data: games, error } = await supabase
    .from('game_titles')
    .select('id, name, cover_url, proxied_cover_url')
    .not('cover_url', 'is', null)
    .is('proxied_cover_url', null)
    .order('id');

  if (error) {
    console.error('❌ Failed to fetch games:', error);
    return;
  }

  console.log(`📊 Found ${games.length} games with covers to migrate\n`);

  let migrated = 0;
  let failed = 0;
  let skipped = 0;

  for (const game of games) {
    console.log(`\n🎮 Processing game ${game.id}: ${game.name}`);
    
    // Skip if cover_url is already a Supabase URL
    if (game.cover_url.includes('supabase')) {
      console.log('  ✓ Cover already proxied');
      skipped++;
      continue;
    }

    // Skip if cover_url is a data URL or invalid
    if (game.cover_url.startsWith('data:') || !game.cover_url.startsWith('http')) {
      console.log('  ⚠️  Skipping invalid cover URL');
      skipped++;
      continue;
    }

    const proxiedUrl = await uploadExternalCover(game.cover_url, game.id);
    
    if (proxiedUrl) {
      // Update database with proxied URL
      console.log('  💾 Updating database...');
      const { error: updateError } = await supabase
        .from('game_titles')
        .update({ proxied_cover_url: proxiedUrl })
        .eq('id', game.id);

      if (updateError) {
        console.error('  ❌ Database update failed:', updateError);
        failed++;
      } else {
        console.log('  ✅ Database updated');
        migrated++;
      }
    } else {
      failed++;
    }

    // Add a small delay to avoid rate limits
    await new Promise(resolve => setTimeout(resolve, 300));
  }

  console.log('\n' + '='.repeat(60));
  console.log('✅ Migration Complete!');
  console.log('='.repeat(60));
  console.log(`Migrated: ${migrated} covers`);
  console.log(`Failed:   ${failed} covers`);
  console.log(`Skipped:  ${skipped} covers`);
  console.log(`Total:    ${games.length} games processed`);
  console.log('='.repeat(60));
}

// Run the migration
migrateGameCovers().catch(console.error);
