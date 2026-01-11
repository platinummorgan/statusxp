/**
 * One-time migration script to copy existing external avatar URLs
 * to Supabase Storage to fix CORS issues
 */

import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

// Helper to download external avatar and upload to Supabase Storage
async function uploadExternalAvatar(externalUrl, userId, platform) {
  try {
    console.log(`[${platform.toUpperCase()}] Downloading avatar for user ${userId}...`);
    
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
    
    // Create a unique filename: platform/userId_timestamp.ext
    const timestamp = Date.now();
    const filename = `${platform}/${userId}_${timestamp}.${extension}`;
    
    console.log(`  ⬆️  Uploading to: ${filename}`);
    
    // Upload to Supabase Storage
    const { data, error } = await supabase.storage
      .from('avatars')
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

    console.log(`  ✅ Success: ${publicUrl}`);
    return publicUrl;
  } catch (error) {
    console.error(`  ❌ Exception:`, error.message);
    return null;
  }
}

async function migrateAvatars() {
  console.log('🚀 Starting avatar migration...\n');

  // Get all profiles with external avatar URLs
  const { data: profiles, error } = await supabase
    .from('profiles')
    .select('id, psn_avatar_url, xbox_avatar_url, steam_avatar_url')
    .or('psn_avatar_url.not.is.null,xbox_avatar_url.not.is.null,steam_avatar_url.not.is.null');

  if (error) {
    console.error('❌ Failed to fetch profiles:', error);
    return;
  }

  console.log(`📊 Found ${profiles.length} profiles with avatars\n`);

  let migratedPsn = 0;
  let migratedXbox = 0;
  let migratedSteam = 0;
  let failedPsn = 0;
  let failedXbox = 0;
  let failedSteam = 0;

  for (const profile of profiles) {
    console.log(`\n👤 Processing user: ${profile.id}`);
    const updates = {};

    // Migrate PSN avatar
    if (profile.psn_avatar_url && !profile.psn_avatar_url.includes('supabase')) {
      console.log('  PSN avatar needs migration...');
      const proxiedUrl = await uploadExternalAvatar(profile.psn_avatar_url, profile.id, 'psn');
      if (proxiedUrl) {
        updates.psn_avatar_url = proxiedUrl;
        migratedPsn++;
      } else {
        failedPsn++;
      }
    } else if (profile.psn_avatar_url && profile.psn_avatar_url.includes('supabase')) {
      console.log('  ✓ PSN avatar already migrated');
    }

    // Migrate Xbox avatar
    if (profile.xbox_avatar_url && !profile.xbox_avatar_url.includes('supabase')) {
      console.log('  Xbox avatar needs migration...');
      const proxiedUrl = await uploadExternalAvatar(profile.xbox_avatar_url, profile.id, 'xbox');
      if (proxiedUrl) {
        updates.xbox_avatar_url = proxiedUrl;
        migratedXbox++;
      } else {
        failedXbox++;
      }
    } else if (profile.xbox_avatar_url && profile.xbox_avatar_url.includes('supabase')) {
      console.log('  ✓ Xbox avatar already migrated');
    }

    // Migrate Steam avatar
    if (profile.steam_avatar_url && !profile.steam_avatar_url.includes('supabase')) {
      console.log('  Steam avatar needs migration...');
      const proxiedUrl = await uploadExternalAvatar(profile.steam_avatar_url, profile.id, 'steam');
      if (proxiedUrl) {
        updates.steam_avatar_url = proxiedUrl;
        migratedSteam++;
      } else {
        failedSteam++;
      }
    } else if (profile.steam_avatar_url && profile.steam_avatar_url.includes('supabase')) {
      console.log('  ✓ Steam avatar already migrated');
    }

    // Update database if we have any new URLs
    if (Object.keys(updates).length > 0) {
      console.log('  💾 Updating database...');
      const { error: updateError } = await supabase
        .from('profiles')
        .update(updates)
        .eq('id', profile.id);

      if (updateError) {
        console.error('  ❌ Database update failed:', updateError);
      } else {
        console.log('  ✅ Database updated');
      }
    }

    // Add a small delay to avoid rate limits
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  console.log('\n' + '='.repeat(60));
  console.log('✅ Migration Complete!');
  console.log('='.repeat(60));
  console.log(`PSN:   ${migratedPsn} migrated, ${failedPsn} failed`);
  console.log(`Xbox:  ${migratedXbox} migrated, ${failedXbox} failed`);
  console.log(`Steam: ${migratedSteam} migrated, ${failedSteam} failed`);
  console.log(`Total: ${migratedPsn + migratedXbox + migratedSteam} avatars migrated`);
  console.log('='.repeat(60));
}

// Run the migration
migrateAvatars().catch(console.error);
