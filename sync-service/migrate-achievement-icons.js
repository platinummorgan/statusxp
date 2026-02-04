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
    // Map platform ID to platform name
    const platformMap = {
      1: 'psn',
      2: 'psn',
      5: 'psn',
      9: 'psn',
      10: 'xbox',
      11: 'xbox',
      12: 'xbox',
      4: 'steam',
      8: 'steam'
    };
    const platformName = platformMap[platformId] || platformId;
    
    console.log(`[PLATFORM ${platformName} ${achievementId}] Downloading icon from:`, externalUrl.substring(0, 80) + '...');
    
    // Download the image from the external URL
    const response = await fetch(externalUrl);
    if (!response.ok) {
      console.error(`  ❌ Failed to download: ${response.status}`);
      return null;
    }

    // Get the image data as a buffer
    const arrayBuffer = await response.arrayBuffer();
    const fileSizeMB = (arrayBuffer.byteLength / (1024 * 1024)).toFixed(2);
    
    // Log file size
    console.log(`  📦 Downloaded: ${fileSizeMB}MB`);
    
    // Determine file extension from content type
    const contentType = response.headers.get('content-type') || 'image/png';
    let extension = 'png';
    if (contentType.includes('jpeg') || contentType.includes('jpg')) extension = 'jpg';
    else if (contentType.includes('gif')) extension = 'gif';
    else if (contentType.includes('webp')) extension = 'webp';
    
    // Create filename: achievement-icons/{platform_name}/{platform_achievement_id}.ext
    const filename = `achievement-icons/${platformName}/${achievementId}.${extension}`;
    
    console.log(`  ⬆️  Uploading to: ${filename}`);
    
    // Upload to Supabase Storage (try with larger files, let Supabase reject if too big)
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

  // Get trophies that either:
  // 1. Have no proxied_icon_url (NULL)
  // 2. Have proxied_icon_url with timestamp pattern (e.g., "27_1768496227219.png")
  const { data: allTrophies, error: fetchError } = await supabase
    .from('achievements')
    .select('platform_id, platform_game_id, platform_achievement_id, name, icon_url, proxied_icon_url')
    .not('icon_url', 'is', null)
    .in('platform_id', [1, 2, 5, 9]); // PlayStation platforms

  if (fetchError) {
    console.error('❌ Failed to fetch trophies:', fetchError);
    return { migrated: 0, failed: 0, skipped: 0 };
  }

  // Filter for trophies needing migration:
  // - icon_url must be external (PSN CDN: image.api.playstation.com or psnobj.prod.dl.playstation.net)
  // - proxied_icon_url is NULL OR has timestamp pattern
  const trophies = allTrophies
    .filter(t => {
      // Must have external PSN URL
      const hasExternalUrl = t.icon_url && 
        (t.icon_url.includes('image.api.playstation.com') || 
         t.icon_url.includes('psnobj.prod.dl.playstation.net'));
      
      if (!hasExternalUrl) return false;
      
      // Must need proxying (NULL or broken timestamp URL)
      const needsProxying = !t.proxied_icon_url || 
        /_\d{13}\.(png|jpg|jpeg|gif|webp)$/i.test(t.proxied_icon_url);
      
      return needsProxying;
    })
    .slice(0, 100); // Batch of 100

  console.log(`📊 Found ${trophies.length} trophies with icons to migrate\n`);

  let migrated = 0;
  let failed = 0;
  let skipped = 0;

  for (const trophy of trophies) {
    console.log(`\n🏆 Processing trophy ${trophy.platform_achievement_id}: ${trophy.name.substring(0, 50)}...`);
    console.log(`  📥 Source: ${trophy.icon_url.substring(0, 80)}...`);

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
  console.log('🎮 Starting Steam achievement icon migration...\n');

  const { data: allAchievements, error: fetchError } = await supabase
    .from('achievements')
    .select('platform_id, platform_game_id, platform_achievement_id, name, icon_url, proxied_icon_url')
    .not('icon_url', 'is', null)
    .in('platform_id', [4, 8]); // Steam platforms

  if (fetchError) {
    console.error('❌ Failed to fetch achievements:', fetchError);
    return { migrated: 0, failed: 0, skipped: 0 };
  }

  // Filter for achievements needing migration:
  // - icon_url must be external Steam CDN
  // - proxied_icon_url is NULL OR has timestamp pattern
  const achievements = allAchievements
    .filter(a => {
      // Must have external Steam URL
      const hasExternalUrl = a.icon_url && 
        (a.icon_url.includes('steamcdn') || 
         a.icon_url.includes('steamstatic') ||
         a.icon_url.includes('cloudflare.steamstatic'));
      
      if (!hasExternalUrl) return false;
      
      // Must need proxying (NULL or broken timestamp URL)
      const needsProxying = !a.proxied_icon_url || 
        /_\d{13}\.(png|jpg|jpeg|gif|webp)$/i.test(a.proxied_icon_url);
      
      return needsProxying;
    })
    .slice(0, 100); // Batch of 100

  console.log(`📊 Found ${achievements.length} Steam achievements to migrate\n`);

  let migrated = 0;
  let failed = 0;
  let skipped = 0;

  for (const achievement of achievements) {
    console.log(`\n🎮 Processing achievement ${achievement.platform_achievement_id}: ${achievement.name.substring(0, 50)}...`);
    console.log(`  📥 Source: ${achievement.icon_url.substring(0, 80)}...`);

    const proxiedUrl = await uploadExternalIcon(achievement.icon_url, achievement.platform_achievement_id, achievement.platform_id);
    
    if (proxiedUrl) {
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

    await new Promise(resolve => setTimeout(resolve, 100));
  }

  return { migrated, failed, skipped, total: achievements.length };
}

// Run migrations in a loop until complete
async function runAllMigrations() {
  console.log('🚀 Starting icon migration for PlayStation and Steam...\n');
  console.log('ℹ️  Xbox skipped - no CORS issues\n');
  
  let totalMigrated = 0;
  let totalFailed = 0;
  let totalSkipped = 0;
  let batchCount = 0;
  
  // Loop until both platforms are done
  while (true) {
    batchCount++;
    console.log(`\n${'='.repeat(60)}`);
    console.log(`Batch #${batchCount}`);
    console.log('='.repeat(60) + '\n');
    
    const psnResults = await migrateTrophyIcons();
    const steamResults = await migrateAchievementIcons();
    
    const batchMigrated = psnResults.migrated + steamResults.migrated;
    const batchFailed = psnResults.failed + steamResults.failed;
    const batchSkipped = psnResults.skipped + steamResults.skipped;
    const batchTotal = psnResults.total + steamResults.total;
    
    totalMigrated += batchMigrated;
    totalFailed += batchFailed;
    totalSkipped += batchSkipped;
    
    console.log(`\n📊 Batch Summary: ✅ ${batchMigrated} migrated, ❌ ${batchFailed} failed, ⏭️ ${batchSkipped} skipped`);
    console.log(`📈 Running Total: ✅ ${totalMigrated} migrated, ❌ ${totalFailed} failed, ⏭️ ${totalSkipped} skipped`);
    
    // Stop if no more records to process
    if (batchTotal === 0) {
      console.log('\n✅ No more records to process!');
      break;
    }
    
    // Stop if batch had no migrations (all skipped/failed)
    if (batchMigrated === 0 && batchTotal > 0) {
      console.log('\n⚠️  No migrations in this batch - may need manual review');
      break;
    }
    
    // Small delay between batches
    console.log('\n⏳ Waiting 2 seconds before next batch...');
    await new Promise(resolve => setTimeout(resolve, 2000));
  }
  
  console.log('\n\n' + '='.repeat(60));
  console.log('📈 FINAL MIGRATION SUMMARY');
  console.log('='.repeat(60));
  console.log(`  ✅ Total migrated: ${totalMigrated}`);
  console.log(`  ❌ Total failed: ${totalFailed}`);
  console.log(`  ⏭️  Total skipped: ${totalSkipped}`);
  console.log(`  📦 Total batches: ${batchCount}`);
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
