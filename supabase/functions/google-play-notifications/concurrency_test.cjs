const { spawn, spawnSync } = require("node:child_process");
const assert = require("node:assert/strict");
assert.equal(process.env.PGHOST, "127.0.0.1");
assert.equal(process.env.PGDATABASE, "statusxp_effective_test");
assert.ok(process.env.PGPORT);
const psql = process.env.TEST_PSQL || "psql";
const args = ["-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1"];
const user = "00000000-0000-4000-8000-000000000050";
const key = `production:${"e".repeat(64)}`;
function sql(query) {
  const r = spawnSync(psql, [...args, "-c", query], {
    encoding: "utf8",
    windowsHide: true,
  });
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
}
function run(query) {
  return new Promise((resolve, reject) => {
    const c = spawn(psql, [
      ...args,
      "-c",
      `SET statement_timeout='5s'; ${query}`,
    ], { windowsHide: true });
    let error = "";
    c.stderr.on("data", (b) => error += b);
    c.on("error", reject);
    c.on("exit", (code) => code === 0 ? resolve() : reject(new Error(error)));
  });
}
(async () => {
  try {
    sql(`INSERT INTO auth.users VALUES('${user}');
      SELECT public.fulfill_verified_store_purchase('${user}','google_play','race_play_1','statusxp_premium_monthly','subscription',
        'SUBSCRIPTION_STATE_ACTIVE',now(),now()+interval '30 days',false,
        jsonb_build_object('subscriptionKey','${key}','accountBound',true,'verifiedAt',now()));`);
    const negative =
      `SELECT public.apply_google_play_notification('9001',repeat('a',64),now()+interval '10 seconds',
      jsonb_build_object('subscriptionKey','${key}','state','SUBSCRIPTION_STATE_EXPIRED','expiresAt',now()),'${user}');`;
    const mobile =
      `SELECT public.fulfill_verified_store_purchase('${user}','google_play','race_play_2','statusxp_premium_monthly','subscription',
      'SUBSCRIPTION_STATE_ACTIVE',now(),now()+interval '60 days',false,
      jsonb_build_object('subscriptionKey','${key}','accountBound',true,'verifiedAt',now()));`;
    await Promise.all([run(negative), run(negative), run(mobile)]);
    assert.equal(
      sql(
        `SELECT public.effective_premium_entitlement('${user}')->>'is_premium'`,
      ),
      "false",
    );
    assert.equal(
      sql(
        "SELECT count(*) FROM public.google_play_notification_receipts WHERE message_id='9001'",
      ),
      "1",
    );
    console.log(
      "Concurrent duplicate expiry notifications and an older mobile verification leave one receipt and no restored coverage.",
    );
  } finally {
    sql(
      `DELETE FROM public.google_play_notification_receipts WHERE message_id='9001';
      DELETE FROM public.google_play_subscription_state WHERE subscription_key='${key}';
      DELETE FROM public.store_subscription_bindings WHERE subscription_key='${key}';
      DELETE FROM public.user_premium_status WHERE user_id='${user}'; DELETE FROM auth.users WHERE id='${user}';`,
    );
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
