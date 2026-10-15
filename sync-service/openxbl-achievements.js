export const OPENXBL_API_BASE = 'https://api.xbl.io/v2';

export function unwrapOpenXblResponse(body) {
  const wrapped = body && Object.hasOwn(body, 'content');
  const status = wrapped && body.code != null ? Number(body.code) : 200;
  if (!Number.isInteger(status) || status < 200 || status >= 300) {
    return { ok: false, status: Number.isInteger(status) ? status : 502, data: null };
  }
  const data = wrapped ? body.content : body;
  if (!data || typeof data !== 'object') return { ok: false, status: 502, data: null };
  return { ok: true, status, data };
}

export function openXblPlayerAchievementsUrl(xuid, titleId, platformId) {
  const user = encodeURIComponent(String(xuid));
  const title = encodeURIComponent(String(titleId));
  return platformId === 10
    ? `${OPENXBL_API_BASE}/achievements/x360/${user}/title/${title}`
    : `${OPENXBL_API_BASE}/achievements/player/${user}/${title}`;
}

export function normalizeXboxAchievement(achievement) {
  const legacy = typeof achievement.unlocked === 'boolean' || typeof achievement.unlockedOnline === 'boolean';
  const reportedTime = achievement.progression?.timeUnlocked ?? achievement.timeUnlocked ?? achievement.unlockTime ?? null;
  const parsedTime = reportedTime ? new Date(reportedTime) : null;
  const knownTime = parsedTime && Number.isFinite(parsedTime.getTime()) && parsedTime.getUTCFullYear() > 1970
    && parsedTime.getTime() <= Date.now() + 24 * 60 * 60 * 1000 ? reportedTime : null;
  return {
    ...achievement,
    id: String(achievement.id),
    progressState: legacy
      ? (!achievement.isRevoked && (achievement.unlocked || achievement.unlockedOnline) ? 'Achieved' : 'NotStarted')
      : (achievement.isRevoked ? 'NotStarted' : achievement.progressState),
    rewards: achievement.rewards ?? [{ type: 'Gamerscore', value: String(achievement.gamerscore ?? 0) }],
    progression: {
      ...achievement.progression,
      timeUnlocked: knownTime,
    },
    timeUnlocked: knownTime,
    unlockTime: knownTime,
  };
}

export function needsXboxAchievementFallback(rows, reportedEarned) {
  const unique = new Map(rows.map(normalizeXboxAchievement).map(row => [row.id, row]));
  const earned = [...unique.values()].filter(row => row.progressState === 'Achieved').length;
  return unique.size === 0 || earned < Math.max(0, Number(reportedEarned) || 0);
}

export function mergeXboxAchievementSources(primary, fallback) {
  const rows = new Map(primary.map(normalizeXboxAchievement).map(row => [row.id, row]));
  for (const candidate of fallback.map(normalizeXboxAchievement)) {
    const existing = rows.get(candidate.id);
    if (!existing) { rows.set(candidate.id, candidate); continue; }
    // A revoked unlock must not be restored from another source. Otherwise,
    // retain confirmed unlocks and their real dates when a fallback has gaps.
    const revoked = existing.isRevoked || candidate.isRevoked;
    const earned = existing.progressState === 'Achieved' ? existing : candidate;
    const time = (existing.progressState === 'Achieved' ? existing.progression?.timeUnlocked : null)
      ?? (candidate.progressState === 'Achieved' ? candidate.progression?.timeUnlocked : null) ?? null;
    rows.set(candidate.id, normalizeXboxAchievement({ ...existing, ...candidate,
      rarity: candidate.rarity ?? existing.rarity,
      isRevoked: Boolean(revoked),
      progressState: revoked ? 'NotStarted' : earned.progressState,
      unlocked: undefined, unlockedOnline: undefined,
      progression: { ...earned.progression, timeUnlocked: time },
    }));
  }
  return [...rows.values()];
}

export async function fetchOpenXblAchievementList(fetchPage, initialUrl) {
  const rows = new Map();
  let url = initialUrl;
  const seenTokens = new Set();
  for (let page = 0; page < 20; page++) {
    const result = await fetchPage(url);
    if (!result.ok) return result;
    const data = result.data;
    if (!Array.isArray(data?.achievements)) throw new Error('OpenXBL achievement response is incomplete');
    for (const achievement of data.achievements) {
      if (achievement.id == null) throw new Error('OpenXBL achievement is missing its ID');
      rows.set(String(achievement.id), normalizeXboxAchievement(achievement));
    }
    const token = data.pagingInfo?.continuationToken;
    if (!token) {
      const expected = Number(data.pagingInfo?.totalRecords);
      if (Number.isFinite(expected) && expected > rows.size) throw new Error('OpenXBL achievement catalogue is truncated');
      return { ...result, data: { ...data, achievements: [...rows.values()] } };
    }
    if (seenTokens.has(token)) throw new Error('OpenXBL achievement pagination repeated a token');
    seenTokens.add(token);
    const next = new URL(initialUrl);
    next.searchParams.set('continuationToken', token);
    url = next.toString();
  }
  throw new Error('OpenXBL achievement pagination exceeded 20 pages');
}

export async function fetchOpenXblLegacyAchievements(fetchPage, xuid, titleId) {
  const catalog = await fetchOpenXblAchievementList(fetchPage,
    `${OPENXBL_API_BASE}/achievements/player/${encodeURIComponent(String(xuid))}/title/${encodeURIComponent(String(titleId))}`);
  if (!catalog.ok) return catalog;
  const progress = await fetchOpenXblAchievementList(fetchPage, openXblPlayerAchievementsUrl(xuid, titleId, 10));
  if (!progress.ok) return progress;
  return { ...catalog, data: { ...catalog.data,
    achievements: mergeLegacyXboxAchievements(catalog.data.achievements, progress.data.achievements) } };
}

export function mergeLegacyXboxAchievements(catalog, progress) {
  const earned = new Map(progress.map(normalizeXboxAchievement).map((row) => [row.id, row]));
  const definitions = new Map(catalog.map(normalizeXboxAchievement).map((row) => [row.id, row]));
  for (const row of earned.values()) {
    if (!definitions.has(row.id)) throw new Error('Legacy earned achievement is missing from its catalogue');
  }
  return [...definitions.values()].map((definition) => {
    const unlock = earned.get(definition.id);
    // The catalogue is not player progress. Only the user-specific legacy
    // response may establish an unlock or earned date.
    return normalizeXboxAchievement({ ...definition, ...(unlock ?? {}),
      unlocked: unlock?.progressState === 'Achieved', unlockedOnline: unlock?.unlockedOnline ?? false,
      timeUnlocked: unlock?.progression?.timeUnlocked ?? null, unlockTime: null,
      progression: { timeUnlocked: unlock?.progression?.timeUnlocked ?? null } });
  });
}

export async function fetchXboxLegacyAchievements(fetchPage, xuid, titleId) {
  const base = `https://achievements.xboxlive.com/users/xuid(${encodeURIComponent(String(xuid))})`;
  const query = `?titleId=${encodeURIComponent(String(titleId))}`;
  const catalog = await fetchOpenXblAchievementList(fetchPage, `${base}/titleachievements${query}`);
  if (!catalog.ok) return catalog;
  const progress = await fetchOpenXblAchievementList(fetchPage, `${base}/achievements${query}`);
  if (!progress.ok) return progress;
  return { ...catalog, data: { ...catalog.data,
    achievements: mergeLegacyXboxAchievements(catalog.data.achievements, progress.data.achievements) } };
}
