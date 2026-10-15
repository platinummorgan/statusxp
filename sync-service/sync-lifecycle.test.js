import test from 'node:test';
import assert from 'node:assert/strict';
import { finishSync, requestSyncCancellation } from './sync-lifecycle.js';

for (const platform of ['psn', 'xbox', 'steam']) {
  test(`${platform} cancellation awaits and validates the atomic result`, async () => {
    const client = { async rpc(name, args) {
      assert.equal(name, 'finish_platform_sync');
      assert.equal(args.p_platform, platform);
      assert.equal(args.p_outcome, 'cancelled');
      assert.equal(args.p_games, 2);
      assert.equal(args.p_achievements, 7);
      return { data: 'cancelled', error: null };
    } };
    assert.equal(await finishSync(client, { platform, userId: 'user', logId: 1,
      outcome: 'cancelled', games: 2, achievements: 7 }), 'cancelled');
  });
}
test('a cancellation write error is not reported as success', async () => {
  await assert.rejects(requestSyncCancellation({ async rpc() { return { error: { message: 'offline' } }; } },
    'user', 'psn'), /Cannot request/);
});
test('failed finalization cannot silently return', async () => {
  await assert.rejects(finishSync({ async rpc() { return { error: { message: 'constraint' } }; } },
    { userId: 'user', platform: 'steam', logId: 1, outcome: 'cancelled' }), /Cannot finish/);
});
test('missing results are failures', async () => {
  const client = { async rpc() { return { data: null, error: null }; } };
  await assert.rejects(requestSyncCancellation(client, 'user', 'xbox'), /Missing/);
  await assert.rejects(finishSync(client, { userId: 'user', platform: 'xbox', logId: 1, outcome: 'completed' }), /Missing/);
});
test('late completion reports cancellation instead of overwriting it', async () => {
  assert.equal(await finishSync({ async rpc() { return { data: 'cancelled' }; } },
    { userId: 'user', platform: 'psn', logId: 1, outcome: 'completed' }), 'cancelled');
});
