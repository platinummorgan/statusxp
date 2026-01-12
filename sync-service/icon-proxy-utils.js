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
      console.error(`[ICON PROXY] Failed to download ${externalUrl}: ${response.status}`);
      return null;
    }

    const arrayBuffer = await response.arrayBuffer();
    
    // Determine file extension
    const contentType = response.headers.get('content-type') || 'image/png';
    let extension = 'png';
    if (contentType.includes('jpeg') || contentType.includes('jpg')) extension = 'jpg';
    else if (contentType.includes('gif')) extension = 'gif';
    else if (contentType.includes('webp')) extension = 'webp';
    
    // Create filename
    const timestamp = Date.now();
    const filename = `achievement-icons/${platform}/${achievementId}_${timestamp}.${extension}`;
    
    // Upload to Supabase Storage
    const { error } = await supabase.storage
      .from('avatars')
      .upload(filename, arrayBuffer, {
        contentType,
        upsert: true,
      });

    if (error) {
      console.error('[ICON PROXY] Upload error:', error);
      return null;
    }

    // Get public URL
    const { data: { publicUrl } } = supabase.storage
      .from('avatars')
      .getPublicUrl(filename);

    return publicUrl;
  } catch (error) {
    console.error('[ICON PROXY] Exception:', error.message);
    return null;
  }
}
