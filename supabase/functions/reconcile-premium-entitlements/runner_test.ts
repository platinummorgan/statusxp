import assert from "node:assert/strict";
import { runReconciliation } from "./runner.ts";
const job = {
  provider: "apple" as const,
  subject: "production:10001",
  user_id: "user",
  lease_token: "lease",
};
Deno.test("empty queue does not call the provider or finish", async () => {
  const result = await runReconciliation({
    claim: async () => null,
    reconcile: async () => {
      throw new Error("Unexpected");
    },
    finish: async () => {
      throw new Error("Unexpected");
    },
  });
  assert.equal(result.processed, 0);
});
Deno.test("successful provider update is settled only after completion", async () => {
  const calls: string[] = [];
  const result = await runReconciliation({
    claim: async () => job,
    reconcile: async () => {
      calls.push("provider");
    },
    finish: async (received, success) => {
      assert.equal(received.lease_token, "lease");
      assert.equal(success, true);
      calls.push("finish");
      return true;
    },
  });
  assert.deepEqual(calls, ["provider", "finish"]);
  assert.equal(result.succeeded, 1);
});
Deno.test("provider failure schedules a retry without revoking access", async () => {
  const result = await runReconciliation({
    claim: async () => job,
    reconcile: async () => {
      throw new Error("unavailable");
    },
    finish: async (_job, success) => {
      assert.equal(success, false);
      return true;
    },
  });
  assert.equal(result.succeeded, 0);
  assert.equal(result.retryScheduled, true);
});
Deno.test("lost lease is reported and settlement failure leaves the durable lease to expire", async () => {
  const deps = {
    claim: async () => job,
    reconcile: async () => {},
    finish: async () => false,
  };
  assert.equal((await runReconciliation(deps)).leaseLost, true);
  await assert.rejects(() =>
    runReconciliation({
      ...deps,
      finish: async () => {
        throw new Error("database");
      },
    })
  );
});
