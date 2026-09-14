import test from 'node:test';
import assert from 'node:assert/strict';
import { refreshLeaderboardsAfterSync, executeRefreshJob, drainLeaderboardRefreshJobs,
  LeaderboardRefreshPendingError } from './leaderboard-refresh.js';

function fixture(rows = []) {
  const calls = [];
  const config = { refreshError: false, throwRefresh: false, insertError: false, finishError: false };
  const client = {
    from(table) {
      assert.equal(table, 'leaderboard_refresh_jobs');
      return { select() { return { eq(_column, id) { return { async maybeSingle() {
        const job = rows.find(row => row.id === id);
        return { data: { completed_at: job?.completed ? 'completed' : null } };
      } }; } }; }, insert(jobs) { return { async select() {
        if (config.insertError) return { error: { message: 'offline' } };
        const inserted = jobs.map((job, i) => ({ ...job, id: String(rows.length + i), due: true }));
        // Keep storage independent of this client instance to model restart.
        rows.push(...inserted);
        return { data: inserted.map(({ id }) => ({ id })), error: null };
      } }; } };
    },
    async rpc(name, args = {}) {
      calls.push([name, args]);
      if (name === 'claim_leaderboard_refresh_job') {
        const job = rows.find(row => row.due && !row.completed && !row.lease_token &&
          (!args.p_job_id || row.id === args.p_job_id));
        if (!job) return { data: [], error: null };
        job.lease_token = 'lease';
        return { data: [{ ...job }], error: null };
      }
      if (name === 'finish_leaderboard_refresh_job') {
        if (config.finishError) return { error: { message: 'offline' } };
        const job = rows.find(row => row.id === args.p_job_id);
        if (!job || job.lease_token !== args.p_lease_token) return { data: false };
        job.lease_token = null;
        job.completed = args.p_error === null;
        job.last_error = args.p_error;
        job.due = false;
        return { data: true, error: null };
      }
      assert.ok(['refresh_statusxp_leaderboard_for_user', 'refresh_psn_leaderboard_cache'].includes(name));
      if (config.throwRefresh) throw new Error('network failure');
      return config.refreshError ? { error: { message: 'private database detail' } } : { data: null, error: null };
    },
  };
  return { client, config, calls, rows };
}

test('PSN refresh completes both persisted obligations', async () => {
  const f = fixture();
  await refreshLeaderboardsAfterSync(f.client, 'user', 'psn');
  assert.deepEqual(f.rows.map(row => row.kind), ['statusxp', 'psn']);
  assert.ok(f.rows.every(row => row.completed));
  assert.deepEqual(f.calls.find(([name]) => name === 'refresh_statusxp_leaderboard_for_user')[1], { p_user_id: 'user' });
});

for (const mode of ['refreshError', 'throwRefresh']) {
  test(`${mode} cannot report success and retries after worker restart`, async () => {
    const f = fixture(); f.config[mode] = true;
    await assert.rejects(refreshLeaderboardsAfterSync(f.client, 'user', 'xbox'), LeaderboardRefreshPendingError);
    assert.equal(f.rows[0].completed, false);
    assert.equal(f.rows[0].last_error, 'Leaderboard refresh RPC failed');
    // SQL controls backoff; make the persistent row due for the restarted worker.
    f.rows[0].due = true;
    const restarted = fixture(f.rows);
    await drainLeaderboardRefreshJobs(restarted.client);
    assert.equal(f.rows[0].completed, true);
    assert.equal(f.rows.length, 1);
    assert.ok(restarted.calls.every(([name]) => !name.includes('sync_achievements')));
  });
}

test('queue write failure prevents refresh and surfaces recovery requirement', async () => {
  const f = fixture(); f.config.insertError = true;
  await assert.rejects(refreshLeaderboardsAfterSync(f.client, 'user', 'steam'), /Operator recovery required/);
  assert.deepEqual(f.calls, []);
});

test('lost completion acknowledgment leaves job recoverable by lease expiry', async () => {
  const f = fixture(); f.config.finishError = true;
  await assert.rejects(refreshLeaderboardsAfterSync(f.client, 'user', 'steam'), LeaderboardRefreshPendingError);
  assert.equal(f.rows[0].lease_token, 'lease');
  assert.notEqual(f.rows[0].completed, true);
  f.rows[0].lease_token = null; // expiry/reclaim is exercised by PostgreSQL tests
  const restarted = fixture(f.rows);
  await drainLeaderboardRefreshJobs(restarted.client);
  assert.equal(f.rows[0].completed, true);
});

test('another worker owning the job cannot be mistaken for completed refresh', async () => {
  const f = fixture();
  const rpc = f.client.rpc;
  f.client.rpc = (name, args) => name === 'claim_leaderboard_refresh_job'
    ? Promise.resolve({ data: [] }) : rpc(name, args);
  await assert.rejects(refreshLeaderboardsAfterSync(f.client, 'user', 'steam'), LeaderboardRefreshPendingError);
  assert.equal(f.rows.length, 1);
});

test('stale lease cannot acknowledge a refresh', async () => {
  const f = fixture([{ id: 'job', kind: 'statusxp', user_id: 'user', lease_token: 'new' }]);
  await assert.rejects(executeRefreshJob(f.client, { ...f.rows[0], lease_token: 'old' }), /lease no longer owned/);
  assert.notEqual(f.rows[0].completed, true);
});

test('background completion before immediate claim counts as completed', async () => {
  const f = fixture();
  const rpc = f.client.rpc;
  f.client.rpc = (name, args) => {
    if (name === 'claim_leaderboard_refresh_job') {
      f.rows[0].completed = true;
      return Promise.resolve({ data: [] });
    }
    return rpc(name, args);
  };
  await refreshLeaderboardsAfterSync(f.client, 'user', 'steam');
});

test('draining respects batch limit and leaves other jobs pending', async () => {
  const f = fixture(Array.from({ length: 3 }, (_, i) => ({
    id: String(i), user_id: 'user', kind: 'statusxp', due: true,
  })));
  await drainLeaderboardRefreshJobs(f.client, 2);
  assert.equal(f.rows.filter(row => row.completed).length, 2);
});
