/**
 * Migration script to proxy achievement/trophy icon URLs through Supabase Storage
 * This fixes CORS issues when displaying achievement icons from PlayStation's image API
 */

import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Load .env from parent directory
dotenv.config({ path: join(__dirname, '..', '.env') });

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Helper to download external icon and upload to Supabase Storage
async function uploadExternalIcon(externalUrl, achievementId, platformId) {
  try {
    console.log(`[PLATFORM ${platformId} ${achievementId}] Downloading icon from:`, externalUrl.substring(0, 80) + '...');
    
    // Download the image from the external URL
    const response = await fetch(externalUrl);
    if (!response.ok) {
      console.error(`  ❌ Failed to download: ${response.status}`);
      return null;
    }

    // Get the image data as a buffer
    const arrayBuffer = await response.arrayBuffer();
    
    // Determine file extension from content type
    const contentType = response.headers.get('content-type') || 'image/png';
    let extension = 'png';
    if (contentType.includes('jpeg') || contentType.includes('jpg')) extension = 'jpg';
    else if (contentType.includes('gif')) extension = 'gif';
    else if (contentType.includes('webp')) extension = 'webp';
    
    // Create filename: achievement-icons/{platform_id}/{platform_achievement_id}.ext
    const filename = `achievement-icons/${platformId}/${achievementId}.${extension}`;
    
    console.log(`  ⬆️  Uploading to: ${filename}`);
    
    // Upload to Supabase Storage
    const { data, error } = await supabase.storage
      .from('avatars') // Using same bucket as avatars and covers
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

async function migrateTrophyIcons() {
  console.log('🏆 Starting PlayStation trophy icon migration...\n');

  const { data: trophies, error } = await supabase
    .from('achievements')
    .select('platform_id, platform_game_id, platform_achievement_id, name, icon_url, proxied_icon_url')
    .not('icon_url', 'is', null)
    .is('proxied_icon_url', null)
    .in('platform_id', [1, 2, 5, 9]) // PlayStation platforms
    .limit(100);

  if (error) {
    console.error('❌ Failed to fetch trophies:', error);
    return { migrated: 0, failed: 0, skipped: 0 };
  }

  console.log(`📊 Found ${trophies.length} trophies with icons to migrate\n`);

  let migrated = 0;
  let failed = 0;
  let skipped = 0;

  for (const trophy of trophies) {
    console.log(`\n🏆 Processing trophy ${trophy.platform_achievement_id}: ${trophy.name.substring(0, 50)}...`);
    
    if (trophy.icon_url.includes('supabase')) {
      console.log('  ✓ Icon already proxied');
      skipped++;
      continue;
    }

    if (trophy.icon_url.startsWith('data:') || !trophy.icon_url.startsWith('http')) {
      console.log('  ⚠️  Skipping invalid icon URL');
      skipped++;
      continue;
    }

    const proxiedUrl = await uploadExternalIcon(trophy.icon_url, trophy.platform_achievement_id, trophy.platform_id);
    
    if (proxiedUrl) {
      console.log('  💾 Updating database...');
      const { error: updateError } = await supabase
        .from('achievements')
        .update({ proxied_icon_url: proxiedUrl })
        .eq('platform_id', trophy.platform_id)
        .eq('platform_game_id', trophy.platform_game_id)
        .eq('platform_achievement_id', trophy.platform_achievement_id);

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

    await new Promise(resolve => setTimeout(resolve, 100));
  }

  return { migrated, failed, skipped, total: trophies.length };
}

async function migrateAchievementIcons() {
  console.log('🎮 Starting Xbox achievement icon migration...\n');

  // Get all achievements with icon URLs that haven't been proxied yet
  const { data: achievements, error } = await supabase
    .from('achievements')
    .select('platform_id, platform_game_id, platform_achievement_id, name, icon_url, proxied_icon_url')
    .not('icon_url', 'is', null)
    .is('proxied_icon_url', null)
    .in('platform_id', [10, 11, 12]) // Xbox platforms only
    .limit(100); // Process in batches to avoid timeout

  if (error) {
    console.error('❌ Failed to fetch achievements:', error);
    return { migrated: 0, failed: 0, skipped: 0 };
  }

  console.log(`📊 Found ${achievements.length} achievements with icons to migrate\n`);

  let migrated = 0;
  let failed = 0;
  let skipped = 0;

  for (const achievement of achievements) {
    console.log(`\n🏆 Processing achievement ${achievement.platform_achievement_id}: ${achievement.name.substring(0, 50)}...`);
    
    // Skip if icon_url is already a Supabase URL
    if (achievement.icon_url.includes('supabase')) {
      console.log('  ✓ Icon already proxied');
      skipped++;
      continue;
    }

    // Skip if icon_url is a data URL or invalid
    if (achievement.icon_url.startsWith('data:') || !achievement.icon_url.startsWith('http')) {
      console.log('  ⚠️  Skipping invalid icon URL');
      skipped++;
      continue;
    }

    const proxiedUrl = await uploadExternalIcon(achievement.icon_url, achievement.platform_achievement_id, achievement.platform_id);
    
    if (proxiedUrl) {
      // Update database with proxied URL
      console.log('  💾 Updating database...');
      const { error: updateError } = await supabase
        .from('achievements')
        .update({ proxied_icon_url: proxiedUrl })
        .eq('platform_id', achievement.platform_id)
        .eq('platform_game_id', achievement.platform_game_id)
        .eq('platform_achievement_id', achievement.platform_achievement_id);

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

    // Small delay to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 100));
  }

  return { migrated, failed, skipped, total: achievements.length };
}

// Run both migrations
async function runAllMigrations() {
  console.log('🚀 Starting icon migration for all platforms...\n');
  
  const xboxResults = await migrateAchievementIcons();
  console.log('\n' + '='.repeat(60) + '\n');
  const psnResults = await migrateTrophyIcons();
  
  console.log('\n\n📈 Total Migration Summary:');
  console.log('  Xbox Achievements:');
  console.log(`    ✅ Successfully migrated: ${xboxResults.migrated}`);
  console.log(`    ❌ Failed: ${xboxResults.failed}`);
  console.log(`    ⏭️  Skipped: ${xboxResults.skipped}`);
  console.log(`    📊 Total processed: ${xboxResults.total}`);
  
  console.log('\n  PlayStation Trophies:');
  console.log(`    ✅ Successfully migrated: ${psnResults.migrated}`);
  console.log(`    ❌ Failed: ${psnResults.failed}`);
  console.log(`    ⏭️  Skipped: ${psnResults.skipped}`);
  console.log(`    📊 Total processed: ${psnResults.total}`);
  
  console.log('\n  Grand Total:');
  console.log(`    ✅ ${xboxResults.migrated + psnResults.migrated} icons migrated`);
  console.log(`    ❌ ${xboxResults.failed + psnResults.failed} failed`);
  console.log(`    ⏭️  ${xboxResults.skipped + psnResults.skipped} skipped`);
  
  if (xboxResults.total === 100 || psnResults.total === 100) {
    console.log('\n⚠️  Note: Hit batch limit. Run again to process more.');
  }
}

runAllMigrations()
  .then(() => {
    console.log('\n✨ Migration complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Migration failed:', error);
    process.exit(1);
  });
