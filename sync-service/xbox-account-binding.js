export function assertXboxIdentity(expected, actual) {
  if (!expected || !actual || String(expected) !== String(actual)) {
    throw new Error('Xbox account changed. Reconnect the original Xbox account and retry.');
  }
}
export async function assertXboxSyncJob(client, userId, logId) {
  if (logId == null) throw new Error('Xbox sync has no tracked job. Start a new sync.');
  const { data, error } = await client.from('xbox_sync_logs').select('user_id,status').eq('id',logId).maybeSingle();
  if (error || !data || data.user_id !== userId || !['pending','syncing'].includes(data.status)) {
    throw new Error('Xbox sync session ended or changed. Start a new sync.');
  }
}
