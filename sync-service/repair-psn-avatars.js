/**
 * One-time repair script for PSN avatars.
 *
 * Use cases:
 * - avatar objects were deleted from storage
 * - users changed PSN avatars and need refresh
 *
 * Usage:
 *   node repair-psn-avatars.js            # refresh only missing/broken hosted avatars
 *   node repair-psn-avatars.js --all      # refresh every linked PSN avatar
 *   node repair-psn-avatars.js --dry-run  # no DB/storage writes
 */

import dotenv from 'dotenv';
import { createClient } from '@supabase/supabase-js';
import * as psnModule from 'psn-api';

dotenv.config();

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

const psnApi = psnModule.default ?? psnModule;
const { exchangeRefreshTokenForAuthTokens, getProfileFromAccountId } = psnApi;

const args = new Set(process.argv.slice(2));
const refreshAll = args.has('--all');
const dryRun = args.has('--dry-run');

async function uploadExternalAvatar(externalUrl, userId) {
  const response = await fetch(externalUrl);
  if (!response.ok) {
    throw new Error(`Avatar download failed: ${response.status}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  const contentType = response.headers.get('content-type') || 'image/jpeg';
  let extension = 'jpg';
  if (contentType.includes('png')) extension = 'png';
  else if (contentType.includes('gif')) extension = 'gif';
  else if (contentType.includes('webp')) extension = 'webp';

  const filename = `user-avatars/psn_${userId}.${extension}`;
  if (!dryRun) {
    const { error } = await supabase.storage
      .from('avatars')
      .upload(filename, arrayBuffer, { contentType, upsert: true });
    if (error) throw error;
  }

  const { data: { publicUrl } } = supabase.storage.from('avatars').getPublicUrl(filename);
  return publicUrl;
}

function extractProfilePayload(rawProfileResponse) {
  if (!rawProfileResponse) return null;
  if (rawProfileResponse.profile) return rawProfileResponse.profile;
  if (Array.isArray(rawProfileResponse.profiles) && rawProfileResponse.profiles.length > 0) {
    return rawProfileResponse.profiles[0];
  }
  return rawProfileResponse;
}

function extractAvatarUrlFromProfile(profile) {
  const normalized = [
    ...(Array.isArray(profile?.avatarUrls) ? profile.avatarUrls.map((a) => ({ size: a?.size, url: a?.avatarUrl || a?.url })) : []),
    ...(Array.isArray(profile?.avatars) ? profile.avatars.map((a) => ({ size: a?.size, url: a?.url || a?.avatarUrl })) : []),
  ].filter((a) => a?.url);

  return (
    normalized.find((a) => String(a.size || '').toLowerCase() === 'm')?.url ||
    normalized.find((a) => String(a.size || '').toLowerCase() === 'l')?.url ||
    normalized[0]?.url ||
    null
  );
}

async function isHostedAvatarMissing(url) {
  if (!url) return true;
  if (!url.includes('/storage/v1/object/public/avatars/')) return false;

  try {
    const response = await fetch(url, { method: 'HEAD' });
    return response.status === 404;
  } catch {
    return true;
  }
}

async function main() {
  console.log('Starting PSN avatar repair...');
  console.log(`Mode: ${refreshAll ? 'all linked users' : 'missing/broken only'}${dryRun ? ' (dry-run)' : ''}`);

  const { data: profiles, error } = await supabase
    .from('profiles')
    .select('id, psn_account_id, psn_refresh_token, psn_avatar_url')
    .not('psn_account_id', 'is', null)
    .not('psn_refresh_token', 'is', null);

  if (error) {
    throw new Error(`Failed to query profiles: ${error.message}`);
  }

  let checked = 0;
  let repaired = 0;
  let skipped = 0;
  let failed = 0;

  for (const profile of profiles || []) {
    checked += 1;
    const shouldRepair = refreshAll || (await isHostedAvatarMissing(profile.psn_avatar_url));
    if (!shouldRepair) {
      skipped += 1;
      continue;
    }

    try {
      const tokens = await exchangeRefreshTokenForAuthTokens(profile.psn_refresh_token);
      const rawProfile = await getProfileFromAccountId(
        { accessToken: tokens.accessToken },
        profile.psn_account_id
      );
      const psnProfile = extractProfilePayload(rawProfile);
      const externalAvatarUrl = extractAvatarUrlFromProfile(psnProfile);

      if (!externalAvatarUrl) {
        skipped += 1;
        continue;
      }

      const hostedAvatarUrl = await uploadExternalAvatar(externalAvatarUrl, profile.id);

      const updates = {
        psn_avatar_url: hostedAvatarUrl,
        psn_access_token: tokens.accessToken,
        psn_refresh_token: tokens.refreshToken || profile.psn_refresh_token,
        psn_token_expires_at: tokens.expiresIn
          ? new Date(Date.now() + (tokens.expiresIn * 1000)).toISOString()
          : null,
      };

      if (psnProfile?.onlineId) {
        updates.psn_online_id = psnProfile.onlineId;
      }
      if (typeof psnProfile?.plus === 'number') {
        updates.psn_is_plus = psnProfile.plus === 1;
      }

      if (!dryRun) {
        const { error: updateError } = await supabase
          .from('profiles')
          .update(updates)
          .eq('id', profile.id);
        if (updateError) throw updateError;
      }

      repaired += 1;
      console.log(`Repaired avatar for user ${profile.id}`);
    } catch (repairError) {
      failed += 1;
      console.error(`Failed to repair user ${profile.id}:`, repairError.message);
    }
  }

  console.log('\nPSN avatar repair complete');
  console.log(`Checked: ${checked}`);
  console.log(`Repaired: ${repaired}`);
  console.log(`Skipped: ${skipped}`);
  console.log(`Failed: ${failed}`);
}

main().catch((err) => {
  console.error('Repair script failed:', err.message);
  process.exit(1);
});
