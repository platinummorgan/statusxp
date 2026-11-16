import { createHash } from 'node:crypto';

export function validXboxCompletionTime(value) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isFinite(date.getTime()) && date.getUTCFullYear() > 1970
    && date.getTime() <= Date.now() ? date.toISOString() : null;
}

// Membership is authoritative only when every required definition was fetched.
// A locked/zero DLC achievement must never influence the completion estimate.
export function extractXboxMythicDetails(titleId, completion, achievements) {
  const groups = (completion ?? []).filter(item => String(item.titleId) === String(titleId))
    .flatMap(item => Object.entries(item.groups ?? {}))
    .filter(([, group]) => group.groupType === 'BaseGame');
  if (groups.length === 0) return null;
  const definitions = new Map(achievements.map(row => [String(row.id), row]));
  const required = new Set();
  for (const [, group] of groups) {
    if (!Array.isArray(group.achievementIds) || group.achievementIds.length === 0) return null;
    for (const id of group.achievementIds) {
      if (id == null || !definitions.has(String(id))) return null;
      required.add(String(id));
    }
  }
  const ids = [...required].sort();
  const rarities = ids.map(id => {
    const raw = definitions.get(id).rarity?.currentPercentage;
    if (raw == null || raw === '' || typeof raw === 'boolean') return null;
    const value = Number(raw);
    return Number.isFinite(value) && value >= 0 && value <= 100 ? value : null;
  });
  // Missing one requirement's rarity makes the minimum uncertain.
  const rarity = rarities.every(value => value !== null) ? Math.min(...rarities) : null;
  const times = groups.map(([, group]) => group.isComplete === true
    ? validXboxCompletionTime(group.completedTime) : null);
  return {
    required_ids: ids,
    membership_revision: createHash('sha256').update(JSON.stringify(ids)).digest('hex'),
    estimated_rarity: rarity,
    completed_at: times.every(Boolean) ? times.sort().at(-1) : null,
    source: 'xbox_live_contract_6',
  };
}

export function needsXboxMythicRefresh(title, metadata) {
  return typeof title.achievement?.isMythic === 'boolean'
    && (metadata?.mythic_schema_version !== 1
      || metadata?.mythic_last_reported !== title.achievement.isMythic
      || (title.achievement.isMythic && metadata?.mythic_rarity_pending === true
        && (!metadata?.last_sync_attempt
          || Date.now() - Date.parse(metadata.last_sync_attempt) > 24 * 60 * 60 * 1000)));
}

export async function saveXboxMythic(client, { userId, xuid, logId, platformId, title, details }) {
  // Missing fields are unknown, not negative native confirmation.
  if (typeof title.achievement?.isMythic !== 'boolean') return;
  const { error } = await client.rpc('record_xbox_mythic', {
    p_user_id: userId, p_xuid: String(xuid), p_sync_log_id: logId,
    p_platform_id: platformId, p_platform_game_id: String(title.titleId),
    p_is_mythic: title.achievement.isMythic, p_details: details,
  });
  if (error) throw new Error('Xbox Mythic could not be saved; retry sync.');
}
