/**
 * Migration script to proxy achievement/trophy icon URLs through Supabase Storage
 * This fixes CORS issues when displaying achievement icons from PlayStation's image API
 */

import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Helper to download external icon and upload to Supabase Storage
async function uploadExternalIcon(externalUrl, achievementId, platform) {
  try {
    console.log(`[${platform.toUpperCase()} ${achievementId}] Downloading icon from:`, externalUrl.substring(0, 80) + '...');
    
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
    
    // Create a unique filename: achievement-icons/platform/achievementId_timestamp.ext
    const timestamp = Date.now();
    const filename = `achievement-icons/${platform}/${achievementId}_${timestamp}.${extension}`;
    
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

async function migrateAchievementIcons() {
  console.log('🚀 Starting achievement icon migration...\n');

  // Get all achievements with icon URLs that haven't been proxied yet
  const { data: achievements, error } = await supabase
    .from('achievements')
    .select('id, name, platform, icon_url, proxied_icon_url')
    .not('icon_url', 'is', null)
    .is('proxied_icon_url', null)
    .order('id')
    .limit(100); // Process in batches to avoid timeout

  if (error) {
    console.error('❌ Failed to fetch achievements:', error);
    return;
  }

  console.log(`📊 Found ${achievements.length} achievements with icons to migrate\n`);

  let migrated = 0;
  let failed = 0;
  let skipped = 0;

  for (const achievement of achievements) {
    console.log(`\n🏆 Processing achievement ${achievement.id}: ${achievement.name.substring(0, 50)}...`);
    
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

    const proxiedUrl = await uploadExternalIcon(achievement.icon_url, achievement.id, achievement.platform);
    
    if (proxiedUrl) {
      // Update database with proxied URL
      console.log('  💾 Updating database...');
      const { error: updateError } = await supabase
        .from('achievements')
        .update({ proxied_icon_url: proxiedUrl })
        .eq('id', achievement.id);

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

  console.log('\n\n📈 Migration Summary:');
  console.log(`  ✅ Successfully migrated: ${migrated}`);
  console.log(`  ❌ Failed: ${failed}`);
  console.log(`  ⏭️  Skipped: ${skipped}`);
  console.log(`  📊 Total processed: ${achievements.length}`);
  
  if (achievements.length === 100) {
    console.log('\n⚠️  Note: Processed 100 achievements (batch limit). Run again to process more.');
  }
}

// Run the migration
migrateAchievementIcons()
  .then(() => {
    console.log('\n✨ Migration complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Migration failed:', error);
    process.exit(1);
  });
