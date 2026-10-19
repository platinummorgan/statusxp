import test from 'node:test';
import assert from 'node:assert/strict';
import { preservePsnImportTimes } from './psn-platform-migration.js';
import { buildVerifiedChange } from './activity-feed-facts.js';
const oldTime = '2026-09-01T12:00:00Z';
const row = { user_id: 'u', platform_id: 5, platform_game_id: 'g', platform_achievement_id: '1', earned_at: '2026-10-19T12:00:00Z' };
const previous = { ...row, platform_id: 2, synced_at: oldTime };

test('platform correction retains the earliest known import timestamp without changing the earned date', () => {
  const result = preservePsnImportTimes([row], [previous, { ...previous, synced_at: '2026-09-02T00:00:00Z' }]);
  assert.equal(result[0].synced_at, oldTime);
  assert.equal(result[0].earned_at, row.earned_at);
  assert.equal(row.synced_at, undefined);
});

test('new trophies and unrelated owners or lists keep their import behavior', () => {
  const unrelated = [{ ...previous, user_id: 'other' }, { ...previous, platform_game_id: 'other' }, { ...previous, platform_achievement_id: '2' }];
  assert.equal(preservePsnImportTimes([row], unrelated)[0], row);
});

test('invalid previous timestamps are ignored and existing earlier import times are retained', () => {
  assert.equal(preservePsnImportTimes([row], [{ ...previous, synced_at: null }])[0], row);
  const earlier = { ...row, synced_at: '2026-08-01T00:00:00Z' };
  assert.equal(preservePsnImportTimes([earlier], [previous])[0], earlier);
});

test('feed verification accepts real additions after excluding a platform correction by its original import time', () => {
  const before = { platinum_count: 0, psn_gold_count: 0, psn_silver_count: 0, psn_bronze_count: 1, synced_at: '2026-10-19T10:00:00Z' };
  const after = { ...before, psn_bronze_count: 2, synced_at: '2026-10-19T14:00:00Z' };
  const definition = { name: 'Example trophy', metadata: { psn_trophy_type: 'bronze' } };
  const migrated = { ...row, achievements: definition };
  const added = { ...row, platform_achievement_id: '2', achievements: definition };
  const games = [{ platform_id: 5, platform_game_id: 'g', name: 'Example game' }];
  assert.equal(buildVerifiedChange('psn', before, after, [migrated, added], games), null);
  const persisted = preservePsnImportTimes([migrated, added], [previous]).map(r => ({ ...r, synced_at: r.synced_at || '2026-10-19T13:00:00Z' }));
  const imported = persisted.filter(r => Date.parse(r.synced_at) >= Date.parse(before.synced_at) && Date.parse(r.synced_at) <= Date.parse(after.synced_at));
  const change = buildVerifiedChange('psn', before, after, imported, games);
  assert.equal(change.change, 1);
  assert.equal(change.bronzeCount, 1);
});
