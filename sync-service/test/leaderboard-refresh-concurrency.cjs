// Run only against an isolated test cluster after applying fixture schema/migration.
const { spawn, spawnSync } = require('node:child_process');
const assert = require('node:assert/strict');
const { createInterface } = require('node:readline');
assert.equal(process.env.PGHOST, '127.0.0.1');
assert.equal(process.env.PGDATABASE, 'statusxp_refresh_test');
assert.ok(process.env.PGPORT);
const psql = process.env.TEST_PSQL || 'psql';
const args = ['-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1'];
const user = '00000000-0000-0000-0000-000000000002';
const firstId = '00000000-0000-0000-0000-000000000010';
const secondId = '00000000-0000-0000-0000-000000000020';
function sql(query) {
  const result = spawnSync(psql, [...args, '-c', query], { encoding: 'utf8', windowsHide: true });
  assert.equal(result.status, 0, result.stderr);
  return result.stdout.trim();
}
function claim() {
  return new Promise((resolve, reject) => {
    const child = spawn(psql, [...args, '-c', 'SELECT id FROM public.claim_leaderboard_refresh_job()'], { windowsHide: true });
    let output = ''; let error = '';
    child.stdout.on('data', chunk => output += chunk);
    child.stderr.on('data', chunk => error += chunk);
    child.on('error', reject);
    child.on('exit', code => code === 0 ? resolve(output.trim()) : reject(new Error(error)));
  });
}
(async () => {
  let locker;
  try {
    sql(`INSERT INTO auth.users(id) VALUES ('${user}');
      INSERT INTO public.leaderboard_refresh_jobs(id,user_id,kind,source_platform) VALUES
      ('${firstId}','${user}','statusxp','steam'), ('${secondId}','${user}','statusxp','xbox');`);
    locker = spawn(psql, args, { windowsHide: true });
    const ready = new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('Lock acquisition timed out')), 5000);
      createInterface({ input: locker.stdout }).on('line', line => {
        if (line === 'LOCK_READY') { clearTimeout(timeout); resolve(); }
      });
      locker.on('error', reject);
    });
    locker.stdin.write(`BEGIN; SELECT id FROM public.leaderboard_refresh_jobs WHERE id='${firstId}' FOR UPDATE; SELECT 'LOCK_READY';\n`);
    await ready;
    assert.equal(sql("SET statement_timeout='1s'; SELECT id FROM public.claim_leaderboard_refresh_job()"), secondId);
    locker.stdin.end('ROLLBACK;\n\\q\n');
    await new Promise(resolve => locker.on('exit', resolve));
    locker = null;
    const results = await Promise.all([claim(), claim()]);
    assert.deepEqual(results.filter(Boolean), [firstId]);
    console.log('SKIP LOCKED and simultaneous exclusive claims passed');
  } finally {
    if (locker) locker.kill();
    sql(`DELETE FROM auth.users WHERE id='${user}'`);
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
