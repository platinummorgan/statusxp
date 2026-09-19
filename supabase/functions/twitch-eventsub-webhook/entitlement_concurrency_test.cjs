// Run only against an isolated test cluster after applying fixture schema/migration.
const { spawn, spawnSync } = require('node:child_process');
const assert = require('node:assert/strict');
const { createInterface } = require('node:readline');
assert.equal(process.env.PGHOST, '127.0.0.1');
assert.equal(process.env.PGDATABASE, 'statusxp_twitch_test');
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
function apply() {
  return new Promise((resolve,reject)=>{
    const child=spawn(psql,[...args,'-c',`SELECT public.apply_twitch_event('concurrent','hash','2026-09-12T12:00:00Z','30',true)`],{windowsHide:true});
    let error='';child.stderr.on('data',c=>error+=c);child.on('error',reject);child.on('exit',code=>code===0?resolve():reject(new Error(error)));
  });
}
(async()=>{
  try {
    sql(`INSERT INTO auth.users VALUES('${user}');INSERT INTO public.profiles VALUES('${user}','30');`);
    await Promise.all([apply(),apply()]);
    assert.equal(sql("SELECT count(*) FROM public.twitch_event_receipts WHERE message_id='concurrent'"),'1');
    assert.equal(sql(`SELECT premium_expires_at='2026-10-15T12:00:00Z'::timestamptz FROM public.user_premium_status WHERE user_id='${user}'`),'t');
    console.log('Concurrent Twitch deliveries commit one receipt and one fixed expiry');
  } finally {
    sql(`DELETE FROM public.twitch_event_receipts WHERE message_id='concurrent';DELETE FROM public.twitch_entitlement_state WHERE twitch_user_id='30';DELETE FROM public.user_premium_status WHERE user_id='${user}';DELETE FROM public.profiles WHERE id='${user}';DELETE FROM auth.users WHERE id='${user}';`);
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
