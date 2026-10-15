export async function assertPlatformSyncOwner(client, userId, platform, accountId, logId) {
 const field = platform === 'psn' ? 'psn_account_id' : 'steam_id';
 const profile = await client.from('profiles').select(`${field},${platform}_sync_status`).eq('id', userId).single();
 if (profile.error || String(profile.data?.[field] ?? '') !== String(accountId) || !['syncing','cancelling'].includes(profile.data?.[`${platform}_sync_status`])) {
  throw new Error('Sync connection changed or is no longer active. Start a new sync.');
 }
 const log = await client.from(`${platform}_sync_logs`).select('status').eq('id', logId).eq('user_id', userId).single();
 if (log.error || !['pending','syncing'].includes(log.data?.status)) throw new Error('Sync job is no longer active for this user.');
 return profile.data[`${platform}_sync_status`];
}
