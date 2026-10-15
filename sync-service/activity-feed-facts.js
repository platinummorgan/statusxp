/** Verified feed facts. Never treat a failed read, re-sync, or import as a live win. */
export async function readAllPages(query, pageSize = 500) {
  const rows = [];
  for (let offset = 0; ; offset += pageSize) {
    const { data, error } = await query().range(offset, offset + pageSize - 1);
    if (error || !Array.isArray(data)) throw new Error(error?.message || 'Missing feed data');
    rows.push(...data);
    if (data.length < pageSize) return rows;
  }
}

const trophyFields = ['platinum_count', 'psn_gold_count', 'psn_silver_count', 'psn_bronze_count'];
const trophyTypes = ['platinum', 'gold', 'silver', 'bronze'];
const key = row => `${row.platform_id}:${row.platform_game_id}`;
const definition = row => Array.isArray(row.achievements) ? row.achievements[0] : row.achievements;
const validCount = value => value !== null && value !== undefined && Number.isSafeInteger(Number(value)) && Number(value) >= 0;

export function buildVerifiedChange(source, before, after, rows, games) {
  const fields = source === 'psn' ? trophyFields : [source === 'xbox' ? 'gamerscore' : 'steam_achievement_count'];
  if (!fields.every(field => validCount(before[field]) && validCount(after[field]))) return null;
  const deltas = fields.map(field => Number(after[field]) - Number(before[field]));
  if (deltas.some(delta => delta < 0) || !deltas.some(delta => delta > 0)) return null;
  const unique = [...new Map(rows.map(row => [`${key(row)}:${row.platform_achievement_id}`, row])).values()];
  if (!unique.length || unique.some(row => !definition(row))) return null;
  let observed;
  if (source === 'psn') {
    observed = trophyTypes.map(type => unique.filter(row => {
      const a = definition(row);
      return (a.is_platinum ? 'platinum' : a.metadata?.psn_trophy_type) === type;
    }).length);
    if (observed.reduce((a, b) => a + b, 0) !== unique.length) return null;
  } else if (source === 'xbox') {
    observed = [unique.reduce((sum, row) => {
      const a = definition(row);
      return sum + Number(a.score_value ?? a.metadata?.gamerscore ?? 0);
    }, 0)];
  } else if (source === 'steam') observed = [unique.length];
  else return null;
  // A reset baseline, repeated upsert, or incomplete page must not fabricate a gain.
  if (deltas.some((delta, i) => delta !== observed[i])) return null;
  const names = new Map(games.map(game => [key(game), game.name]));
  const grouped = new Map();
  for (const row of unique) {
    const name = names.get(key(row));
    if (!name) return null; // Never guess from the user's last played game.
    const group = grouped.get(key(row)) || { name, count: 0, latest: '' };
    group.count++;
    group.latest = group.latest > row.earned_at ? group.latest : row.earned_at;
    grouped.set(key(row), group);
  }
  const ordered = [...grouped.values()].sort((a, b) => b.count - a.count || String(b.latest).localeCompare(String(a.latest)));
  const titles = [...new Set(ordered.map(game => game.name))];
  const gameTitle = titles.slice(0, 3).join(', ') + (titles.length > 3 ? ` + ${titles.length - 3} more games` : '');
  const totalBefore = fields.reduce((sum, field) => sum + Number(before[field]), 0);
  const totalAfter = fields.reduce((sum, field) => sum + Number(after[field]), 0);
  const cutoff = Date.parse(after.synced_at) - 7 * 86400000;
  const isImport = totalBefore === 0 || unique.some(row => !Number.isFinite(Date.parse(row.earned_at)) || Date.parse(row.earned_at) < cutoff);
  const rareTrophies = unique.map(row => {
    const a = definition(row);
    return { name: a.name, rarity: a.rarity_global, gameTitle: names.get(key(row)), type: a.metadata?.psn_trophy_type };
  }).filter(a => a.name && a.rarity !== null && Number.isFinite(Number(a.rarity)) && Number(a.rarity) > 0 && Number(a.rarity) < 10)
    .sort((a, b) => Number(a.rarity) - Number(b.rarity));
  // A named unlock gives the writer something concrete to celebrate even on a small update.
  const highlights = unique.map(row => {
    const a = definition(row);
    return { name: a.name, description: a.description || '', gameTitle: names.get(key(row)),
      rarity: a.rarity_global, earnedAt: row.earned_at,
      importance: a.is_platinum ? 4 : ({ gold: 3, silver: 2, bronze: 1 }[a.metadata?.psn_trophy_type] || 1) };
  }).filter(a => a.name).sort((a, b) => {
    const rare = value => Number(value) > 0 && Number(value) < 10 ? Number(value) : 101;
    return rare(a.rarity) - rare(b.rarity) || b.importance - a.importance || String(b.earnedAt).localeCompare(String(a.earnedAt));
  });
  return {
    highlight: highlights[0] || null,
    type: source === 'psn' ? 'trophy_detail' : source === 'xbox' ? 'gamerscore_gain' : 'steam_achievement_gain',
    source, oldValue: totalBefore, newValue: totalAfter, change: totalAfter - totalBefore,
    goldCount: source === 'psn' ? deltas[1] : 0,
    silverCount: source === 'psn' ? deltas[2] : 0,
    bronzeCount: source === 'psn' ? deltas[3] : 0,
    platinumChange: source === 'psn' ? deltas[0] : 0,
    platinumNew: source === 'psn' ? Number(after.platinum_count) : undefined,
    platinumGames: [...new Set(unique.filter(row => definition(row).is_platinum).map(row => names.get(key(row))))],
    gameTitle, gameTitles: titles.slice(0, 3), gameCount: grouped.size,
    titleCount: titles.length, isImport, rareTrophies: rareTrophies.slice(0, 1),
    // Global StatusXP can be stale or updated by another platform's concurrent sync.
    // Do not attribute that cache difference to this accomplishment.
    changeType: isImport ? 'import' : source === 'psn' && deltas[0] ? 'milestone' : 'small',
  };
}
