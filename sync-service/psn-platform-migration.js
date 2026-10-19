// Platform reclassification must retain when an existing trophy was first imported.
// Match the owner, trophy list and trophy ID; another game's IDs are unrelated.
export function preservePsnImportTimes(rows, previousImports) {
  const key = row => `${row.user_id}:${row.platform_game_id}:${row.platform_achievement_id}`;
  const times = new Map();
  for (const row of previousImports) {
    const time = Date.parse(row.synced_at);
    if (!Number.isFinite(time)) continue;
    const prior = times.get(key(row));
    if (!prior || time < Date.parse(prior)) times.set(key(row), row.synced_at);
  }
  return rows.map(row => {
    const previous = times.get(key(row));
    if (!previous) return row;
    // Never move an already earlier import time forward.
    if (Number.isFinite(Date.parse(row.synced_at)) && Date.parse(row.synced_at) <= Date.parse(previous)) return row;
    return { ...row, synced_at: previous };
  });
}
