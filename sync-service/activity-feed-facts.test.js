import test from 'node:test';
import assert from 'node:assert/strict';
import { buildVerifiedChange, readAllPages } from './activity-feed-facts.js';
const before = { platinum_count: 4253, psn_gold_count: 10, psn_silver_count: 20, psn_bronze_count: 30, synced_at: '2026-09-20T08:00:00Z' };
const after = { ...before, platinum_count: 4255, synced_at: '2026-09-20T09:00:00Z' };
const games = [1, 2].map(id => ({ platform_id: 1, platform_game_id: String(id), name: 'PAINT BALL' }));
const rows = games.map(game => ({ ...game, platform_achievement_id: '0', earned_at: '2026-09-19T12:00:00Z', achievements: { name: 'PAINT BALL', is_platinum: true } }));
test('two distinct lists keep their title and actual platinum gain', () => {
 const change = buildVerifiedChange('psn', before, after, rows, games);
 assert.equal(change.platinumChange, 2); assert.equal(change.gameTitle, 'PAINT BALL'); assert.equal(change.gameCount, 2); assert.equal(change.isImport, false);
});
test('false zero baseline cannot announce a whole collection', () => {
 assert.equal(buildVerifiedChange('psn', { ...before, platinum_count: 0 }, after, rows, games), null);
});
test('unchanged re-sync and incomplete context produce no story', () => {
 assert.equal(buildVerifiedChange('psn', after, after, rows, games), null);
 assert.equal(buildVerifiedChange('psn', before, after, rows.slice(0, 1), games), null);
 assert.equal(buildVerifiedChange('psn', before, after, rows, []), null);
});
test('historical trophies are explicitly imports', () => {
 assert.equal(buildVerifiedChange('psn', before, after, rows.map(row => ({ ...row, earned_at: '2012-01-01T00:00:00Z' })), games).isImport, true);
});
test('Steam reports all contributing games, not just the latest', () => {
 const change = buildVerifiedChange('steam', { steam_achievement_count: 10 }, { steam_achievement_count: 12, synced_at: after.synced_at }, rows, games.map((g, i) => ({ ...g, name: i ? 'Hades' : 'Portal' })));
 assert.equal(change.gameTitle, 'Portal, Hades');
});
test('Xbox cannot invent a new total from repeated scored rows', () => {
 assert.equal(buildVerifiedChange('xbox', { gamerscore: 100 }, { gamerscore: 110 }, rows.map(row => ({ ...row, achievements: { score_value: 10 } })), games), null);
});
test('rarity uses actual rarity_global and rejects missing rarity', () => {
 const change = buildVerifiedChange('psn', before, after, rows.map((row, i) => ({ ...row, achievements: { ...row.achievements, rarity_global: i ? null : 0.8 } })), games);
 assert.equal(change.rareTrophies.length, 1); assert.equal(change.rareTrophies[0].rarity, 0.8);
});
test('pagination covers every row and fails closed on query errors', async () => {
 const records = Array.from({ length: 1001 }, (_, id) => ({ id }));
 assert.equal((await readAllPages(() => ({ range: async (a, b) => ({ data: records.slice(a, b + 1) }) }))).length, 1001);
 await assert.rejects(readAllPages(() => ({ range: async () => ({ error: { message: 'timeout' } }) })), /timeout/);
});
