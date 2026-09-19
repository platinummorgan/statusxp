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
function admit(userId) {
  return new Promise((resolve,reject)=>{
    const child=spawn(psql,[...args,'-c',`SELECT public.admit_provider_request('${userId}','youtube')->>'allowed'`],{windowsHide:true});
    let output='',error=''; child.stdout.on('data',c=>output+=c); child.stderr.on('data',c=>error+=c);
    child.on('error',reject); child.on('exit',code=>code===0?resolve(output.trim()):reject(new Error(error)));
  });
}
(async()=>{
  let original;
  try {
    original=sql("SELECT row_to_json(p) FROM public.provider_quota_policy p WHERE provider='youtube'");
    sql(`INSERT INTO auth.users VALUES('${firstId}'),('${secondId}'); UPDATE public.provider_quota_policy SET global_daily=1 WHERE provider='youtube';`);
    const results=await Promise.all([admit(firstId),admit(secondId)]);
    assert.deepEqual(results.sort(),['false','true']);
    assert.equal(sql("SELECT used FROM public.provider_quota_usage WHERE provider='youtube' AND subject='global'"),'1');
    console.log('Concurrent users cannot exceed shared provider ceiling');
  } finally {
    sql(`DELETE FROM auth.users WHERE id IN ('${firstId}','${secondId}'); DELETE FROM public.provider_quota_usage WHERE provider='youtube';`);
    if(original) sql(`UPDATE public.provider_quota_policy SET global_daily=${JSON.parse(original).global_daily} WHERE provider='youtube'`);
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
