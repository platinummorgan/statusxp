const { spawn, spawnSync } = require("node:child_process");
const assert = require("node:assert/strict");
assert.equal(process.env.PGHOST, "127.0.0.1");
assert.equal(process.env.PGDATABASE, "statusxp_effective_test");
assert.ok(process.env.PGPORT);
const psql = process.env.TEST_PSQL || "psql";
const args = ["-X", "-q", "-A", "-t", "-v", "ON_ERROR_STOP=1"];
const user = "00000000-0000-4000-8000-000000000080";
function sql(query) {
  const r = spawnSync(psql, [...args, "-c", query], {
    encoding: "utf8",
    windowsHide: true,
  });
  assert.equal(r.status, 0, r.stderr);
  return r.stdout.trim();
}
function claim() {
  return new Promise((resolve, reject) => {
    const c = spawn(psql, [
      ...args,
      "-c",
      "SET statement_timeout='5s'; SELECT coalesce(json_agg(row_to_json(j)),'[]'::json) FROM public.claim_entitlement_reconciliation(ARRAY['apple'],false) j;",
    ], { windowsHide: true });
    let error = "", output = "";
    c.stderr.on("data", (b) => error += b);
    c.stdout.on("data", (b) => output += b);
    c.on("error", reject);
    c.on(
      "exit",
      (code) =>
        code === 0
          ? resolve(JSON.parse(output.trim()))
          : reject(new Error(error)),
    );
  });
}
(async () => {
  try {
    sql(
      `INSERT INTO auth.users VALUES('${user}'); SELECT public.bind_store_subscription('${user}','app_store','production:900080',NULL,true);`,
    );
    const claims = await Promise.all([claim(), claim()]);
    assert.deepEqual(claims.map((rows) => rows.length).sort(), [0, 1]);
    const [job] = claims.flat();
    assert.equal(
      sql(
        `SELECT public.finish_entitlement_reconciliation('apple','production:900080','${job.lease_token}',true)`,
      ),
      "t",
    );
    assert.deepEqual(await claim(), []);
    console.log(
      "Concurrent workers claim one reconciliation lease; successful settlement schedules the next check.",
    );
  } finally {
    sql(
      `DELETE FROM public.store_subscription_bindings WHERE platform='app_store' AND subscription_key='production:900080'; DELETE FROM auth.users WHERE id='${user}';`,
    );
  }
})().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
