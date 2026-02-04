/**
 * Shared utility to proxy external achievement/trophy icons through Supabase Storage
 * This fixes CORS issues when displaying icons on the web
 */

/**
 * Download external icon and upload to Supabase Storage
 * @param {string} externalUrl - The external icon URL
 * @param {string} achievementId - The achievement ID
 * @param {string} platform - The platform (psn, xbox, steam)
 * @param {object} supabase - Supabase client
 * @returns {Promise<string|null>} - The proxied URL or null if failed
 */
export async function uploadExternalIcon(externalUrl, achievementId, platform, supabase) {
  // Skip if no URL provided
  if (!externalUrl) {
    return null;
  }

  // Skip if not a valid HTTP URL
  if (!externalUrl.startsWith('http')) {
    return null;
  }

  try {
    // First, check if file already exists in storage (exact match only, no timestamps)
    const extensions = ['png', 'jpg', 'jpeg', 'gif', 'webp'];
    for (const ext of extensions) {
      const filename = `achievement-icons/${platform}/${achievementId}.${ext}`;
      const { data: existingFiles } = await supabase.storage
        .from('avatars')
        .list(`achievement-icons/${platform}`, {
          search: `${achievementId}.${ext}`
        });
      
      // Check if exact filename exists (not timestamped)
      if (existingFiles && existingFiles.some(f => f.name === `${achievementId}.${ext}`)) {
        const { data: { publicUrl } } = supabase.storage
          .from('avatars')
          .getPublicUrl(filename);
        console.log(`[ICON PROXY] ✓ Using existing ${platform}/${achievementId}.${ext}`);
        return publicUrl;
      }
    }

    // File doesn't exist, download and upload it
    const response = await fetch(externalUrl);
    if (!response.ok) {
      console.error(`[ICON PROXY] Failed to download ${platform}/${achievementId} from ${externalUrl}: HTTP ${response.status}`);
      return null;
    }

    const arrayBuffer = await response.arrayBuffer();
    const maxBytes = parseInt(process.env.MAX_ICON_UPLOAD_BYTES || '5242880', 10); // 5 MB default
    if (arrayBuffer.byteLength > maxBytes) {
      console.warn(`[ICON PROXY] Skipping ${platform}/${achievementId}: ${arrayBuffer.byteLength} bytes exceeds ${maxBytes}`);
      return externalUrl;
    }
    
    // Determine file extension
    const contentType = response.headers.get('content-type') || 'image/png';
    let extension = 'png';
    if (contentType.includes('jpeg') || contentType.includes('jpg')) extension = 'jpg';
    else if (contentType.includes('gif')) extension = 'gif';
    else if (contentType.includes('webp')) extension = 'webp';
    
    // Create filename without timestamp to prevent duplicates
    const filename = `achievement-icons/${platform}/${achievementId}.${extension}`;
    
    // Upload to Supabase Storage
    const { error } = await supabase.storage
      .from('avatars')
      .upload(filename, arrayBuffer, {
        contentType,
        upsert: false, // Don't overwrite since we checked it doesn't exist
      });

    if (error) {
      console.error(`[ICON PROXY] Failed to upload ${platform}/${achievementId} to storage:`, error.message);
      return null;
    }

    // Get public URL
    const { data: { publicUrl } } = supabase.storage
      .from('avatars')
      .getPublicUrl(filename);

    console.log(`[ICON PROXY] ✅ Successfully proxied ${platform}/${achievementId}`);
    return publicUrl;
  } catch (error) {
    console.error(`[ICON PROXY] Exception for ${platform}/${achievementId}:`, error.message);
    return null;
  }
}

/**
 * Download external game cover and upload to Supabase Storage
 * @param {string} externalUrl - The external cover URL
 * @param {number} platformId - The platform ID
 * @param {string} gameId - The game ID
 * @param {object} supabase - Supabase client
 * @returns {Promise<string|null>} - The proxied URL or null if failed
 */
export async function uploadGameCover(externalUrl, platformId, gameId, supabase) {
  // Skip if already a Supabase URL
  if (!externalUrl || externalUrl.includes('supabase')) {
    return externalUrl;
  }

  // Skip if not a valid HTTP URL
  if (!externalUrl.startsWith('http')) {
    return externalUrl;
  }

  try {
    // Download the image
    const response = await fetch(externalUrl);
    if (!response.ok) {
      console.error(`[COVER PROXY] Failed to download ${platformId}/${gameId} from ${externalUrl}: HTTP ${response.status}`);
      return null;
    }

    const arrayBuffer = await response.arrayBuffer();
    const maxBytes = parseInt(process.env.MAX_COVER_UPLOAD_BYTES || '10485760', 10); // 10 MB default
    if (arrayBuffer.byteLength > maxBytes) {
      console.warn(`[COVER PROXY] Skipping ${platformId}/${gameId}: ${arrayBuffer.byteLength} bytes exceeds ${maxBytes}`);
      return externalUrl;
    }
    
    // Determine file extension
    const contentType = response.headers.get('content-type') || 'image/png';
    let extension = 'png';
    if (contentType.includes('jpeg') || contentType.includes('jpg')) extension = 'jpg';
    else if (contentType.includes('gif')) extension = 'gif';
    else if (contentType.includes('webp')) extension = 'webp';
    
    // Create filename: game-covers/{platform_id}/{game_id}.ext
    const filename = `${platformId}/${gameId}.${extension}`;
    
    // Upload to Supabase Storage (game-covers bucket)
    const { error } = await supabase.storage
      .from('game-covers')
      .upload(filename, arrayBuffer, {
        contentType,
        upsert: true,
      });

    if (error) {
      console.error(`[COVER PROXY] Failed to upload ${platformId}/${gameId} to storage:`, error.message);
      return null;
    }

    // Get public URL
    const { data: { publicUrl } } = supabase.storage
      .from('game-covers')
      .getPublicUrl(filename);

    console.log(`[COVER PROXY] ✅ Successfully proxied ${platformId}/${gameId}`);
    return publicUrl;
  } catch (error) {
    console.error(`[COVER PROXY] Exception for ${platformId}/${gameId}:`, error.message);
    return null;
  }
}
