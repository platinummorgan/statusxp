const { spawn, spawnSync } = require('node:child_process');
const { createInterface } = require('node:readline');
const assert = require('node:assert/strict');
assert.equal(process.env.PGHOST, '127.0.0.1');
assert.equal(process.env.PGDATABASE, 'statusxp_effective_test');
assert.ok(process.env.PGPORT);
const psql = process.env.TEST_PSQL || 'psql';
const args = ['-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1'];
const user = '00000000-0000-4000-8000-000000000030';
function sql(query) {
  const r = spawnSync(psql, [...args, '-c', query], { encoding: 'utf8', windowsHide: true });
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
}
function session(name) {
  const child = spawn(psql, args, { windowsHide: true, env: { ...process.env, PGAPPNAME: name } });
  let error = '';
  child.stderr.on('data', c => error += c);
  const done = new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('exit', code => code === 0 ? resolve() : reject(new Error(error)));
  });
  done.catch(() => {});
  return { child, done };
}
(async () => {
  let owner, event;
  try {
    sql(`INSERT INTO auth.users VALUES('${user}'); INSERT INTO public.profiles(id) VALUES('${user}');
      SELECT public.bind_verified_twitch_account('${user}','30');
      SELECT public.apply_twitch_event('race-initial','h0',now(),'30',true);`);
    owner = session('twitch-disconnect-fixture');
    const lines = createInterface({ input: owner.child.stdout });
    const locked = new Promise(resolve => lines.on('line', line => { if (line === 'locked') resolve(); }));
    owner.child.stdin.write(`BEGIN; SELECT set_config('request.jwt.claim.sub','${user}',true);
      SELECT id FROM auth.users WHERE id='${user}' FOR UPDATE; SELECT 'locked';\n`);
    await Promise.race([locked, owner.done.then(() => { throw new Error('Lock session ended early'); })]);
    event = session('twitch-event-fixture');
    event.child.stdin.end("SELECT public.apply_twitch_event('race-pending','h1',now()+interval '1 second','30',true);\n");
    let waiting = false;
    for (let attempt = 0; attempt < 100; attempt++) {
      waiting = sql("SELECT count(*) FROM pg_stat_activity WHERE application_name='twitch-event-fixture' AND wait_event_type='Lock'") === '1';
      if (waiting) break;
      await new Promise(resolve => setTimeout(resolve, 20));
    }
    assert.ok(waiting, 'Event must be waiting on the user lock before disconnect');
    owner.child.stdin.end('SELECT public.disconnect_my_twitch_account(); COMMIT;\n');
    await Promise.all([owner.done, event.done]);
    assert.equal(sql(`SELECT public.effective_premium_entitlement('${user}')->>'is_premium'`), 'false');
    assert.equal(sql(`SELECT count(*) FROM public.twitch_account_bindings WHERE user_id='${user}'`), '0');
    assert.equal(sql("SELECT count(*) FROM public.twitch_event_receipts WHERE message_id='race-pending'"), '1');
    console.log('A webhook waiting on the user lock cannot restore premium after disconnect.');
  } finally {
    for (const s of [owner, event]) if (s && s.child.exitCode === null) s.child.kill();
    await Promise.allSettled([owner?.done, event?.done]);
    sql(`DELETE FROM public.twitch_event_receipts WHERE message_id IN ('race-initial','race-pending');
      DELETE FROM public.twitch_entitlement_state WHERE twitch_user_id='30';
      DELETE FROM public.user_premium_status WHERE user_id='${user}';
      DELETE FROM public.profiles WHERE id='${user}'; DELETE FROM auth.users WHERE id='${user}';`);
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
