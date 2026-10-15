import test from 'node:test';
import assert from 'node:assert/strict';
import { partitionXboxUnlockRows, saveUndatedXboxUnlocks } from './undated-xbox-unlocks.js';

test('undated confirmed rows stay separate and receive no substitute date', () => {
  const key = { user_id: 'u', platform_id: 10, platform_game_id: 'g', platform_achievement_id: 'a' };
  const { dated, undated } = partitionXboxUnlockRows([
    { ...key, earned_at: '2025-01-01T00:00:00Z' }, { ...key, platform_achievement_id: 'b', earned_at: null },
  ], 'xbox_live');
  assert.equal(dated.length, 1);
  assert.equal(undated.length, 1);
  assert.equal(Object.hasOwn(undated[0], 'earned_at'), false);
  assert.equal(undated[0].evidence_source, 'xbox_live');
});
test('undated persistence checks every chunk and propagates failures', async () => {
  let writes = 0;
  const client = { from(table) {
    assert.equal(table, 'user_undated_achievements');
    return { async upsert() { writes++; return { error: writes === 2 ? { message: 'offline' } : null }; } };
  } };
  await assert.rejects(saveUndatedXboxUnlocks(client, [{}, {}, {}], 1), /Failed to save/);
  assert.equal(writes, 2);
});
