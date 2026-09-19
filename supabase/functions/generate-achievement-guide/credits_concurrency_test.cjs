// Run only against an isolated test cluster after applying fixture schema/migration.
const { spawn, spawnSync } = require('node:child_process');
const assert = require('node:assert/strict');
const { createInterface } = require('node:readline');
assert.equal(process.env.PGHOST, '127.0.0.1');
assert.equal(process.env.PGDATABASE, 'statusxp_ai_test');
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
function reserve(id) {
  return new Promise((resolve, reject) => {
    const child = spawn(psql, [...args, '-c', `SELECT public.reserve_ai_guide('${user}','${id}',repeat('a',64))->>'state'`], { windowsHide: true });
    let output = ''; let error = '';
    child.stdout.on('data', chunk => output += chunk);
    child.stderr.on('data', chunk => error += chunk);
    child.on('error', reject);
    child.on('exit', code => code === 0 ? resolve(output.trim()) : reject(new Error(error)));
  });
}
(async () => {
  try {
    sql(`INSERT INTO auth.users VALUES ('${user}'); INSERT INTO public.user_ai_credits VALUES ('${user}',1,now());`);
    const results = await Promise.all([reserve(firstId), reserve(secondId)]);
    assert.deepEqual(results.sort(), ['busy','reserved']);
    assert.equal(sql(`SELECT pack_credits FROM public.user_ai_credits WHERE user_id='${user}'`), '0');
    const id = sql(`SELECT request_id FROM public.ai_guide_requests WHERE user_id='${user}'`);
    const duplicates = await Promise.all([reserve(id), reserve(id)]);
    assert.deepEqual(duplicates, ['pending','pending']);
    sql(`SELECT public.finish_ai_guide('${user}','${id}',NULL); SELECT public.finish_ai_guide('${user}','${id}',NULL);`);
    assert.equal(sql(`SELECT pack_credits FROM public.user_ai_credits WHERE user_id='${user}'`), '1');
    console.log('Concurrent reservations, duplicate requests and single refund passed');
  } finally {
    sql(`DELETE FROM public.user_ai_credits WHERE user_id='${user}'; DELETE FROM auth.users WHERE id='${user}';`);
  }
})().catch(error => { console.error(error); process.exitCode=1; });
