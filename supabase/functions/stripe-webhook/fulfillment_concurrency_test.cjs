// Run only against an isolated test cluster after applying fixture schema/migration.
const { spawn, spawnSync } = require('node:child_process');
const assert = require('node:assert/strict');
const { createInterface } = require('node:readline');
assert.equal(process.env.PGHOST, '127.0.0.1');
assert.equal(process.env.PGDATABASE, 'statusxp_stripe_test');
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
function claim(eventId) {
  return new Promise((resolve,reject)=>{
    const child=spawn(psql,[...args,'-c',`SELECT public.claim_stripe_event('${eventId}','checkout.session.completed','checkout:cs_concurrent')`],{windowsHide:true});
    let output='',error='';child.stdout.on('data',c=>output+=c);child.stderr.on('data',c=>error+=c);
    child.on('error',reject);child.on('exit',code=>code===0?resolve(JSON.parse(output.trim())):reject(new Error(error)));
  });
}
(async()=>{
  try {
    const results=await Promise.all([claim('evt_concurrent1'),claim('evt_concurrent2')]);
    assert.deepEqual(results.map(r=>r.state).sort(),['busy','claimed']);
    const index=results.findIndex(r=>r.state==='claimed');
    const id=index===0?'evt_concurrent1':'evt_concurrent2';
    sql(`SELECT public.finish_stripe_event('${id}','${results[index].token}','{"kind":"ignored"}');`);
    assert.equal((await claim(id)).state,'done');
    assert.equal((await claim(index===0?'evt_concurrent2':'evt_concurrent1')).state,'claimed');
    console.log('Concurrent Stripe deliveries use one resource lease; committed retry is idempotent');
  } finally {
    sql("DELETE FROM public.stripe_webhook_events WHERE event_id IN ('evt_concurrent1','evt_concurrent2'); DELETE FROM public.stripe_resource_leases WHERE resource='checkout:cs_concurrent';");
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
