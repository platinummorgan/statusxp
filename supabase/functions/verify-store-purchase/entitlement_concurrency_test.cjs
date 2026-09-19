const { spawn, spawnSync } = require('node:child_process');
const assert = require('node:assert/strict');
assert.equal(process.env.PGHOST, '127.0.0.1');
assert.equal(process.env.PGDATABASE, 'statusxp_effective_test');
assert.ok(process.env.PGPORT);
const psql = process.env.TEST_PSQL || 'psql';
const args = ['-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1'];
const users = ['00000000-0000-4000-8000-000000000040', '00000000-0000-4000-8000-000000000041'];
function sql(query) {
  const r = spawnSync(psql, [...args, '-c', query], { encoding: 'utf8', windowsHide: true });
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
}
function claim(user, transaction) {
  return new Promise((resolve, reject) => {
    const child = spawn(psql, [...args, '-c', `SET statement_timeout='5s';
      SELECT public.fulfill_verified_store_purchase('${user}','app_store','${transaction}',
        'statusxp_premium_monthly','subscription','ACTIVE',now(),now()+interval '30 days',false,
        jsonb_build_object('subscriptionKey','production:99999','accountBound',true,'verifiedAt',now()));`], { windowsHide: true });
    let error = '';
    child.stderr.on('data', c => error += c);
    child.on('error', reject);
    child.on('exit', code => resolve({ code, error }));
  });
}
(async () => {
  try {
    sql(`INSERT INTO auth.users VALUES('${users[0]}'),('${users[1]}');`);
    const results = await Promise.all(users.map((u, i) => claim(u, `race_store_${i}`)));
    assert.equal(results.filter(r => r.code === 0).length, 1);
    assert.match(results.find(r => r.code !== 0).error, /Subscription belongs to another account/);
    assert.equal(sql("SELECT count(*) FROM public.store_purchase_events WHERE subscription_key='production:99999'"), '1');
    assert.equal(sql("SELECT count(*) FROM public.store_subscription_bindings WHERE subscription_key='production:99999'"), '1');
    console.log('Concurrent subscription claims bind one owner and fulfill exactly one period.');
  } finally {
    sql(`DELETE FROM public.store_subscription_bindings WHERE subscription_key='production:99999';
      DELETE FROM public.user_premium_status WHERE user_id IN ('${users[0]}','${users[1]}');
      DELETE FROM auth.users WHERE id IN ('${users[0]}','${users[1]}');`);
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
