const { spawn, spawnSync } = require("node:child_process");
const assert = require("node:assert/strict");
assert.equal(process.env.PGHOST, "127.0.0.1");
assert.equal(process.env.PGDATABASE, "statusxp_effective_test");
assert.ok(process.env.PGPORT);
const psql = process.env.TEST_PSQL || "psql";
const args = ["-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1"];
const user = "00000000-0000-4000-8000-000000000092";
function sql(query) {
  const r = spawnSync(psql, [...args, "-c", query], {
    encoding: "utf8",
    windowsHide: true,
  });
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
}
function claim(event, type) {
  return new Promise((resolve, reject) => {
    const child = spawn(psql, [
      ...args,
      "-c",
      `SET statement_timeout='5s'; SELECT public.claim_stripe_event('${event}','${type}','subscription:sub_race19');`,
    ], { windowsHide: true });
    let output = "", error = "";
    child.stdout.on("data", (b) => output += b);
    child.stderr.on("data", (b) => error += b);
    child.on("error", reject);
    child.on(
      "exit",
      (code) =>
        code === 0
          ? resolve({ event, ...JSON.parse(output.trim()) })
          : reject(new Error(error)),
    );
  });
}
(async () => {
  try {
    sql(
      `INSERT INTO auth.users VALUES('${user}'); SELECT public.bind_stripe_customer('${user}','cus_race19');
      INSERT INTO public.stripe_subscriptions VALUES('sub_race19','cus_race19','active',now()+interval '1 day',now());`,
    );
    const claims = await Promise.all([
      claim("reconcile_race19", "subscription.reconciliation"),
      claim("evt_race19", "customer.subscription.updated"),
    ]);
    assert.deepEqual(claims.map((c) => c.state).sort(), ["busy", "claimed"]);
    const winner = claims.find((c) => c.state === "claimed");
    // A provider lookup that outlives its lease must not overwrite a later cancellation.
    sql(
      "UPDATE public.stripe_resource_leases SET expires_at=clock_timestamp() WHERE resource='subscription:sub_race19'",
    );
    const current = await claim(
      "evt_current19",
      "customer.subscription.deleted",
    );
    assert.equal(current.state, "claimed");
    const data = (status) =>
      `jsonb_build_object('kind','subscription','subscription_id','sub_race19','customer_id','cus_race19','user_id','${user}','status','${status}','expires_at',now()+interval '30 days')`;
    sql(
      `SELECT public.finish_stripe_event('evt_current19','${current.token}',${
        data("canceled")
      })`,
    );
    const stale = spawnSync(psql, [
      ...args,
      "-c",
      `SELECT public.finish_stripe_event('${winner.event}','${winner.token}',${
        data("active")
      })`,
    ], { encoding: "utf8", windowsHide: true });
    assert.notEqual(stale.status, 0);
    assert.match(stale.stderr, /Lease expired/);
    assert.equal(
      sql(
        `SELECT public.effective_premium_entitlement('${user}')->>'is_premium'`,
      ),
      "false",
    );
    assert.equal(
      sql(
        "SELECT count(*) FROM public.claim_entitlement_reconciliation(ARRAY['stripe'],false)",
      ),
      "0",
    );
    console.log(
      "Scheduled and webhook connections share one Stripe lease; an expired lookup cannot undo cancellation.",
    );
  } finally {
    sql(
      `DELETE FROM public.stripe_resource_leases WHERE resource='subscription:sub_race19';
      DELETE FROM public.stripe_webhook_events WHERE event_id IN ('reconcile_race19','evt_race19','evt_current19');
      DELETE FROM public.stripe_subscriptions WHERE subscription_id='sub_race19';
      DELETE FROM public.stripe_customers WHERE customer_id='cus_race19';
      DELETE FROM public.user_premium_status WHERE user_id='${user}'; DELETE FROM auth.users WHERE id='${user}';`,
    );
  }
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
