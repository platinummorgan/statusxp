export class LeaderboardRefreshPendingError extends Error {
  constructor() {
    super('Sync data saved; leaderboard refresh pending. A background retry is queued.');
    this.name = 'LeaderboardRefreshPendingError';
  }
}

async function checkedRpc(client, name, args) {
  const { data, error } = await client.rpc(name, args);
  if (error) throw new Error(`${name} failed`);
  return data;
}

// Each queued entry is a separate obligation. A new sync cannot be lost when
// another worker finishes an older refresh for the same user.
export async function refreshLeaderboardsAfterSync(client, userId, platform) {
  if (!['psn', 'xbox', 'steam'].includes(platform)) throw new Error('Invalid refresh platform');
  const kinds = platform === 'psn' ? ['statusxp', 'psn'] : ['statusxp'];
  const { data: jobs, error } = await client.from('leaderboard_refresh_jobs')
    .insert(kinds.map(kind => ({ user_id: userId, kind, source_platform: platform })))
    .select('id');
  if (error || jobs?.length !== kinds.length) {
    throw new Error('Sync data saved, but leaderboard retry could not be recorded. Operator recovery required.');
  }
  let complete = true;
  for (const job of jobs) {
    try {
      const claimed = await checkedRpc(client, 'claim_leaderboard_refresh_job', { p_job_id: job.id });
      if (claimed?.length) {
        if (!await executeRefreshJob(client, claimed[0])) complete = false;
      } else {
        // A background worker may have completed this row between insert and claim.
        const { data, error } = await client.from('leaderboard_refresh_jobs')
          .select('completed_at').eq('id', job.id).maybeSingle();
        if (error || !data?.completed_at) complete = false;
      }
    } catch {
      // The durable row remains available after its lease expires.
      complete = false;
    }
  }
  if (!complete) throw new LeaderboardRefreshPendingError();
}

export async function executeRefreshJob(client, job) {
  let failure = null;
  try {
    if (job.kind === 'statusxp') {
      await checkedRpc(client, 'refresh_statusxp_leaderboard_for_user', { p_user_id: job.user_id });
    } else if (job.kind === 'psn') {
      await checkedRpc(client, 'refresh_psn_leaderboard_cache');
    } else {
      throw new Error('Unknown refresh kind');
    }
  } catch {
    // Persist a category, never raw database errors or request credentials.
    failure = 'Leaderboard refresh RPC failed';
  }
  const finished = await checkedRpc(client, 'finish_leaderboard_refresh_job', {
    p_job_id: job.id, p_lease_token: job.lease_token, p_error: failure,
  });
  if (!finished) throw new Error('Leaderboard refresh lease no longer owned');
  if (failure) {
    console.warn('Leaderboard refresh failed; durable retry scheduled');
    return false;
  }
  console.log('Leaderboard refresh complete');
  return true;
}

export async function drainLeaderboardRefreshJobs(client, limit = 10) {
  for (let i = 0; i < limit; i++) {
    const jobs = await checkedRpc(client, 'claim_leaderboard_refresh_job', {});
    if (!jobs?.length) return;
    await executeRefreshJob(client, jobs[0]);
  }
}

export function startLeaderboardRefreshWorker(createClient) {
  let running = false;
  let client;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      client ??= createClient();
      await drainLeaderboardRefreshJobs(client);
    } catch {
      console.error('Leaderboard retry worker unavailable; queued jobs retained for retry');
    } finally {
      running = false;
    }
  };
  const timer = setInterval(tick, 30_000);
  timer.unref();
  void tick();
  return () => clearInterval(timer);
}
