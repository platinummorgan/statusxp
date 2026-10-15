import test from 'node:test';
import assert from 'node:assert/strict';
import { unwrapOpenXblResponse, openXblPlayerAchievementsUrl, normalizeXboxAchievement,
  fetchOpenXblAchievementList, fetchOpenXblLegacyAchievements, fetchXboxLegacyAchievements } from './openxbl-achievements.js';

test('wrapped and direct responses produce the same achievement data', () => {
  const data = { achievements: [{ id: 1 }] };
  assert.deepEqual(unwrapOpenXblResponse({ code: 200, content: data }).data, data);
  assert.deepEqual(unwrapOpenXblResponse(data).data, data);
});
test('an upstream error inside HTTP 200 is still an error', () => {
  assert.equal(unwrapOpenXblResponse({ code: 403, content: {} }).ok, false);
  assert.equal(unwrapOpenXblResponse({ code: 429, content: {} }).status, 429);
  assert.equal(unwrapOpenXblResponse({ code: 200, content: null }).ok, false);
});
test('Xbox 360 uses its dedicated endpoint', () => {
  assert.equal(openXblPlayerAchievementsUrl('user', 'title', 10), 'https://api.xbl.io/v2/achievements/x360/user/title/title');
  assert.equal(openXblPlayerAchievementsUrl('user', 'title', 11), 'https://api.xbl.io/v2/achievements/player/user/title');
});
test('legacy unlocks, score and zero rarity are retained', () => {
  const row = normalizeXboxAchievement({ id: 72, unlocked: true, gamerscore: 20,
    timeUnlocked: '2025-05-26T00:32:16Z', rarity: { currentPercentage: 0 } });
  assert.equal(row.id, '72');
  assert.equal(row.progressState, 'Achieved');
  assert.equal(row.rewards[0].value, '20');
  assert.equal(row.progression.timeUnlocked, '2025-05-26T00:32:16Z');
  assert.equal(row.rarity.currentPercentage, 0);
  assert.equal(normalizeXboxAchievement({ id: 1, unlocked: true, isRevoked: true }).progressState, 'NotStarted');
  assert.equal(normalizeXboxAchievement({ id: 1, unlocked: false }).progression.timeUnlocked, null);
});
test('all pages are fetched, IDs normalized, duplicates removed', async () => {
  const urls = [];
  const result = await fetchOpenXblAchievementList(async (url) => {
    urls.push(url);
    return { ok: true, data: urls.length === 1
      ? { achievements: [{ id: 1 }], pagingInfo: { continuationToken: 'next' } }
      : { achievements: [{ id: 1 }, { id: 2 }], pagingInfo: { totalRecords: 2 } } };
  }, 'https://api.xbl.io/v2/achievements/player/user/title');
  assert.equal(result.data.achievements.length, 2);
  assert.match(urls[1], /continuationToken=next/);
});
test('repeated tokens and truncated catalogues cannot report success', async () => {
  await assert.rejects(fetchOpenXblAchievementList(async () => ({ ok: true,
    data: { achievements: [{ id: 1 }], pagingInfo: { continuationToken: 'same' } } }),
  'https://api.xbl.io/v2/achievements/player/user/title'), /repeated/);
  await assert.rejects(fetchOpenXblAchievementList(async () => ({ ok: true,
    data: { achievements: [{ id: 1 }], pagingInfo: { totalRecords: 2 } } }),
  'https://api.xbl.io/v2/achievements/player/user/title'), /truncated/);
});
test('legacy catalogue totals and player unlocks are combined without borrowing catalogue unlocks', async () => {
  const result = await fetchOpenXblLegacyAchievements(async (url) => ({ ok: true, data: {
    achievements: url.includes('/x360/')
      ? [{ id: 1, unlocked: true, timeUnlocked: '2025-01-01T00:00:00Z', gamerscore: 10 }]
      : [{ id: 1, name: 'Earned' }, { id: 2, name: 'Locked', unlocked: true, timeUnlocked: '2024-01-01T00:00:00Z' }],
  } }), 'user', 'title');
  assert.equal(result.data.achievements.length, 2);
  assert.equal(result.data.achievements[0].progressState, 'Achieved');
  assert.equal(result.data.achievements[1].progressState, 'NotStarted');
  assert.equal(result.data.achievements[1].progression.timeUnlocked, null);
});
test('direct legacy Xbox requests combine catalogue and progress for the linked user', async () => {
  const urls = [];
  const result = await fetchXboxLegacyAchievements(async (url) => {
    urls.push(url);
    return { ok: true, data: { achievements: url.includes('titleachievements')
      ? [{ id: 1 }, { id: 2 }] : [{ id: 1, unlocked: true, gamerscore: 10 }] } };
  }, '123', '456');
  assert.match(urls[0], /xuid\(123\)\/titleachievements\?titleId=456/);
  assert.match(urls[1], /xuid\(123\)\/achievements\?titleId=456/);
  assert.equal(result.data.achievements.length, 2);
  assert.equal(result.data.achievements[0].progressState, 'Achieved');
  assert.equal(result.data.achievements[1].progressState, 'NotStarted');
});
test('offline or sentinel timestamps remain unknown', () => {
  for (const time of [null, '0001-01-01T00:00:00Z', '1970-01-01T00:00:00Z', 'invalid']) {
    const row = normalizeXboxAchievement({ id: 1, unlocked: true, timeUnlocked: time });
    assert.equal(row.progressState, 'Achieved');
    assert.equal(row.progression.timeUnlocked, null);
    assert.equal(row.timeUnlocked, null);
  }
});

import { needsXboxAchievementFallback, mergeXboxAchievementSources } from './openxbl-achievements.js';

test('a nonempty catalogue with missing player unlocks still requires fallback', () => {
  const rows = [{ id: 1, progressState: 'Achieved' }, { id: 2, progressState: 'NotStarted' }];
  assert.equal(needsXboxAchievementFallback(rows, 2), true);
  assert.equal(needsXboxAchievementFallback(rows, 1), false);
  assert.equal(needsXboxAchievementFallback([rows[0], rows[0]], 2), true);
  assert.equal(needsXboxAchievementFallback([], 0), true);
});

test('fallback unlocks merge by ID without losing confirmed dates or rarity', () => {
  const rows = mergeXboxAchievementSources([
    { id: 1, progressState: 'Achieved', progression: { timeUnlocked: '2025-01-01T00:00:00Z' }, rarity: { currentPercentage: 0 } },
    { id: 2, progressState: 'NotStarted' },
  ], [
    { id: 1, progressState: 'NotStarted' },
    { id: 2, unlocked: true, timeUnlocked: null },
  ]);
  assert.equal(rows.length, 2);
  assert.equal(rows[0].progressState, 'Achieved');
  assert.equal(rows[0].progression.timeUnlocked, '2025-01-01T00:00:00Z');
  assert.equal(rows[0].rarity.currentPercentage, 0);
  assert.equal(rows[1].progressState, 'Achieved');
  assert.equal(rows[1].progression.timeUnlocked, null);
});

test('revoked modern unlocks cannot be restored by a fallback', () => {
  assert.equal(normalizeXboxAchievement({ id: 1, progressState: 'Achieved', isRevoked: true }).progressState, 'NotStarted');
  const rows = mergeXboxAchievementSources([{ id: 1, progressState: 'Achieved', isRevoked: true }], [{ id: 1, unlocked: true }]);
  assert.equal(rows[0].progressState, 'NotStarted');
});
