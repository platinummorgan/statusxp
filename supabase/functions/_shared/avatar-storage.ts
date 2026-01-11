/**
 * Avatar Storage Utility
 * 
 * Downloads external platform avatars and uploads to Supabase Storage
 * to avoid CORS issues when displaying avatars on web
 */

import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

/**
 * Downloads an external avatar image and uploads it to Supabase Storage
 * Returns the public URL from Supabase Storage
 */
export async function uploadExternalAvatar(
  supabase: SupabaseClient,
  externalUrl: string,
  userId: string,
  platform: 'psn' | 'xbox' | 'steam'
): Promise<string | null> {
  try {
    console.log(`[AVATAR STORAGE] Downloading ${platform} avatar from:`, externalUrl);
    
    // Download the image from the external URL
    const response = await fetch(externalUrl);
    if (!response.ok) {
      console.error(`[AVATAR STORAGE] Failed to download avatar: ${response.status}`);
      return null;
    }

    // Get the image data as a blob
    const blob = await response.blob();
    const arrayBuffer = await blob.arrayBuffer();
    
    // Determine file extension from content type
    const contentType = response.headers.get('content-type') || 'image/jpeg';
    let extension = 'jpg';
    if (contentType.includes('png')) extension = 'png';
    else if (contentType.includes('gif')) extension = 'gif';
    else if (contentType.includes('webp')) extension = 'webp';
    
    // Create a unique filename: platform/userId_timestamp.ext
    const timestamp = Date.now();
    const filename = `${platform}/${userId}_${timestamp}.${extension}`;
    
    console.log(`[AVATAR STORAGE] Uploading to Supabase Storage: ${filename}`);
    
    // Upload to Supabase Storage
    const { data, error } = await supabase.storage
      .from('avatars')
      .upload(filename, arrayBuffer, {
        contentType,
        upsert: true,
      });

    if (error) {
      console.error('[AVATAR STORAGE] Upload error:', error);
      return null;
    }

    // Get the public URL
    const { data: { publicUrl } } = supabase.storage
      .from('avatars')
      .getPublicUrl(filename);

    console.log(`[AVATAR STORAGE] Successfully uploaded avatar:`, publicUrl);
    return publicUrl;
  } catch (error) {
    console.error('[AVATAR STORAGE] Exception:', error);
    return null;
  }
}

/**
 * Deletes an avatar from Supabase Storage
 */
export async function deleteAvatar(
  supabase: SupabaseClient,
  publicUrl: string
): Promise<boolean> {
  try {
    // Extract the path from the public URL
    // URL format: https://[project].supabase.co/storage/v1/object/public/avatars/platform/filename
    const urlParts = publicUrl.split('/avatars/');
    if (urlParts.length !== 2) {
      console.error('[AVATAR STORAGE] Invalid URL format');
      return false;
    }
    
    const path = urlParts[1];
    console.log(`[AVATAR STORAGE] Deleting avatar: ${path}`);
    
    const { error } = await supabase.storage
      .from('avatars')
      .remove([path]);

    if (error) {
      console.error('[AVATAR STORAGE] Delete error:', error);
      return false;
    }

    console.log('[AVATAR STORAGE] Successfully deleted avatar');
    return true;
  } catch (error) {
    console.error('[AVATAR STORAGE] Exception:', error);
    return false;
  }
}
