const { spawn, spawnSync } = require("node:child_process");
const assert = require("node:assert/strict");
assert.equal(process.env.PGHOST, "127.0.0.1");
assert.equal(process.env.PGDATABASE, "statusxp_effective_test");
assert.ok(process.env.PGPORT);
const psql = process.env.TEST_PSQL || "psql";
const args = ["-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1"];
const user = "00000000-0000-4000-8000-000000000060";
const key = "production:1000050";
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
      SELECT public.fulfill_verified_store_purchase('${user}','app_store','race_apple_1','statusxp_premium_monthly','subscription',
        'ACTIVE',now(),now()+interval '30 days',false,
        jsonb_build_object('subscriptionKey','${key}','accountBound',true,'verifiedAt',now(),'appleStatus',1));`);
    const negative =
      `SELECT public.apply_apple_notification('00000000-0000-4000-8000-000000000070',repeat('a',64),now()+interval '10 seconds',
      jsonb_build_object('subscriptionKey','${key}','status',5,'expiresAt',now()),'${user}');`;
    const mobile =
      `SELECT public.fulfill_verified_store_purchase('${user}','app_store','race_apple_2','statusxp_premium_monthly','subscription',
      'ACTIVE',now(),now()+interval '60 days',false,
      jsonb_build_object('subscriptionKey','${key}','accountBound',true,'verifiedAt',now(),'appleStatus',1));`;
    await Promise.all([run(negative), run(negative), run(mobile)]);
    assert.equal(
      sql(
        `SELECT public.effective_premium_entitlement('${user}')->>'is_premium'`,
      ),
      "false",
    );
    assert.equal(
      sql(
        "SELECT count(*) FROM public.apple_notification_receipts WHERE message_id='00000000-0000-4000-8000-000000000070'",
      ),
      "1",
    );
    console.log(
      "Concurrent duplicate revocation notifications and an older mobile verification leave one receipt and no restored coverage.",
    );
  } finally {
    sql(
      `DELETE FROM public.apple_notification_receipts WHERE message_id='00000000-0000-4000-8000-000000000070';
      DELETE FROM public.apple_subscription_state WHERE subscription_key='${key}';
      DELETE FROM public.store_subscription_bindings WHERE subscription_key='${key}';
      DELETE FROM public.user_premium_status WHERE user_id='${user}'; DELETE FROM auth.users WHERE id='${user}';`,
    );
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
