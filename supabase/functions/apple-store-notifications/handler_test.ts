import assert from "node:assert/strict";
import { type AppleDependencies, createAppleHandler } from "./handler.ts";
import { appleSnapshot } from "./snapshot.ts";
import { resolveAppleStatus } from "../_shared/apple-subscription.ts";
const id = "00000000-0000-4000-8000-000000000001";
const request = () =>
  new Request("https://test.invalid", {
    method: "POST",
    body: JSON.stringify({ signedPayload: "fixture-jws" }),
  });
function fixture(changes: Partial<AppleDependencies> = {}) {
  const calls: string[] = [];
  const handle = createAppleHandler({
    verify: async () => {
      calls.push("verify");
      return { id, originalId: "10001", sandbox: false, accountToken: null };
    },
    seen: async () => false,
    lookup: async () => {
      calls.push("lookup");
      return {
        subscriptionKey: "production:10001",
        status: 5,
        expiresAt: "2026-10-12T00:00:00Z",
        accountToken: null,
        transactionId: "20001",
        purchasedAt: null,
      };
    },
    apply: async (_id, _hash, _time, state) => {
      calls.push(`apply:${state?.status ?? "test"}`);
    },
    ...changes,
  });
  return { calls, handle };
}
Deno.test("Apple notification verifies then reconciles current status before acknowledgement", async () => {
  const f = fixture();
  assert.equal((await f.handle(request())).status, 204);
  assert.deepEqual(f.calls, ["verify", "lookup", "apply:5"]);
});
Deno.test("failed signature, provider and database never acknowledge a notification", async () => {
  for (const key of ["verify", "lookup", "apply"] as const) {
    const f = fixture({
      [key]: async () => {
        throw new Error("failure");
      },
    });
    assert.equal((await f.handle(request())).status, 503);
    assert.ok(!f.calls.some((c) => c.startsWith("apply")));
  }
});
Deno.test("Apple replay skips the API and tests commit a receipt only", async () => {
  const duplicate = fixture({ seen: async () => true });
  assert.equal((await duplicate.handle(request())).status, 204);
  assert.deepEqual(duplicate.calls, ["verify"]);
  const test = fixture({
    verify: async () => ({
      id,
      originalId: null,
      sandbox: true,
      accountToken: null,
    }),
  });
  assert.equal((await test.handle(request())).status, 204);
  assert.deepEqual(test.calls, ["apply:test"]);
});
Deno.test("different account claims cannot be reconciled", async () => {
  const f = fixture({
    verify: async () => ({
      id,
      originalId: "10001",
      sandbox: false,
      accountToken: "a",
    }),
    lookup: async () => ({
      subscriptionKey: "production:10001",
      status: 1,
      expiresAt: null,
      accountToken: "b",
      transactionId: "20001",
      purchasedAt: null,
    }),
  });
  assert.equal((await f.handle(request())).status, 503);
  assert.deepEqual(f.calls, []);
});
Deno.test("malformed and oversized Apple bodies do not reach signature verification", async () => {
  for (
    const [body, status] of [["{}", 400], ["x".repeat(128001), 413]] as const
  ) {
    const f = fixture();
    assert.equal(
      (await f.handle(
        new Request("https://test.invalid", { method: "POST", body }),
      )).status,
      status,
    );
    assert.deepEqual(f.calls, []);
  }
});
const transaction = {
  bundleId: "com.statusxp.statusxp",
  productId: "statusxp_premium_monthly",
  originalTransactionId: "10001",
  transactionId: "20001",
  environment: "Production",
  expiresDate: 100000,
  purchaseDate: 1000,
};
const renewal = {
  originalTransactionId: "10001",
  environment: "Production",
  gracePeriodExpiresDate: 200000,
};
Deno.test("Apple grace uses signed renewal expiry, while revoked transactions override active status", () => {
  assert.equal(
    appleSnapshot(4, transaction, renewal, "10001", false).expiresAt,
    new Date(200000).toISOString(),
  );
  assert.equal(
    appleSnapshot(1, transaction, renewal, "10001", false).expiresAt,
    new Date(100000).toISOString(),
  );
  assert.equal(
    appleSnapshot(
      1,
      { ...transaction, revocationDate: 1001 },
      renewal,
      "10001",
      false,
    ).status,
    5,
  );
  for (const status of [2, 3, 5]) {
    assert.equal(
      appleSnapshot(status, transaction, renewal, "10001", false).status,
      status,
    );
  }
});
Deno.test("Apple snapshot rejects wrong lineage, product, environment and missing grace expiry", () => {
  for (
    const changes of [
      { originalTransactionId: "other" },
      { productId: "other" },
      { bundleId: "other" },
      { environment: "Sandbox" },
    ]
  ) {
    assert.throws(() =>
      appleSnapshot(1, { ...transaction, ...changes }, renewal, "10001", false)
    );
  }
  assert.throws(() =>
    appleSnapshot(
      4,
      transaction,
      { ...renewal, gracePeriodExpiresDate: undefined },
      "10001",
      false,
    )
  );
  assert.throws(() => appleSnapshot(6, transaction, renewal, "10001", false));
});
Deno.test("current status selects only the requested original transaction and verifies both JWS values", async () => {
  const calls: string[] = [];
  const verifier = {
    verifyAndDecodeTransaction: async (signed: string) => {
      calls.push(signed);
      return transaction;
    },
    verifyAndDecodeRenewalInfo: async (signed: string) => {
      calls.push(signed);
      return renewal;
    },
  };
  const row = {
    originalTransactionId: "10001",
    status: 4,
    signedTransactionInfo: "transaction-jws",
    signedRenewalInfo: "renewal-jws",
  };
  const body = {
    bundleId: transaction.bundleId,
    environment: "Production",
    data: [{
      lastTransactions: [{ ...row, originalTransactionId: "unrelated" }, row],
    }],
  };
  assert.equal(
    (await resolveAppleStatus(body, "10001", false, verifier)).status,
    4,
  );
  assert.deepEqual(calls.sort(), ["renewal-jws", "transaction-jws"]);
  await assert.rejects(() =>
    resolveAppleStatus(
      { ...body, data: [{ lastTransactions: [row, row] }] },
      "10001",
      false,
      verifier,
    )
  );
  await assert.rejects(() =>
    resolveAppleStatus(body, "missing", false, verifier)
  );
  await assert.rejects(() => resolveAppleStatus(body, "10001", true, verifier));
  await assert.rejects(() =>
    resolveAppleStatus(body, "10001", false, {
      ...verifier,
      verifyAndDecodeRenewalInfo: async () => {
        throw new Error("Bad renewal signature");
      },
    })
  );
});
