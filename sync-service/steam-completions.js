import { ensureSteamCompletionPolicy } from './steam-achievement-sets.js';

export async function recordSteamCompletion(client, { userId, steamId, logId, appId, schema, playerAchievements },
  { ensurePolicy = ensureSteamCompletionPolicy } = {}) {
  const names = schema.map(row => row.name);
  if (!names.length || names.some(name => typeof name !== 'string' || !name)
    || new Set(names).size !== names.length) throw new Error('Steam completion schema is incomplete');
  const states = playerAchievements.map(row => ({
    apiname: row.apiname, achieved: row.achieved, unlocktime: row.unlocktime ?? 0,
  }));
  if (states.some(row => typeof row.apiname !== 'string' || ![0, 1].includes(row.achieved))
    || new Set(states.map(row => row.apiname)).size !== states.length
    || states.length !== names.length || states.some(row => !names.includes(row.apiname))) {
    throw new Error('Steam completion progress is incomplete');
  }
  await ensurePolicy(client, appId, names);
  const { data, error } = await client.rpc('record_steam_completion', {
    p_user_id: userId, p_steam_id: String(steamId), p_sync_log_id: logId,
    p_app_id: String(appId), p_schema_names: names, p_player_state: states,
  });
  if (error) throw new Error('Steam completion could not be saved; retry sync.');
  return data;
}

export async function markSteamCompletionsSynced(client, { userId, steamId, logId }) {
  const { error } = await client.rpc('mark_steam_completions_synced', {
    p_user_id: userId, p_steam_id: String(steamId), p_sync_log_id: logId,
  });
  if (error) throw new Error('Steam completion sync status could not be saved.');
}
