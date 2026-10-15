export async function requestSyncCancellation(client, userId, platform) {
  const { data, error } = await client.rpc('request_sync_cancellation', {
    p_user_id: userId, p_platform: platform,
  });
  if (error) throw new Error(`Cannot request sync cancellation: ${error.message}`);
  if (typeof data !== 'string') throw new Error('Missing cancellation result');
  return data;
}

export async function finishSync(client, { userId, platform, logId, outcome, games, achievements, error: message }) {
  const { data, error } = await client.rpc('finish_platform_sync', {
    p_user_id: userId, p_platform: platform, p_log_id: logId, p_outcome: outcome,
    p_games: games ?? null, p_achievements: achievements ?? null, p_error: message ?? null,
  });
  if (error) throw new Error(`Cannot finish sync: ${error.message}`);
  if (!['completed', 'cancelled', 'failed'].includes(data)) throw new Error('Missing terminal sync result');
  return data;
}
