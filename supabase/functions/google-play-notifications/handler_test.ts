import assert from "node:assert/strict";
import {
  createGoogleNotificationHandler,
  type GoogleNotificationDependencies,
} from "./handler.ts";
import { parseGoogleSnapshot } from "./snapshot.ts";
const subscription = "projects/test/subscriptions/play";
function request(
  payload: any = {
    packageName: "com.statusxp.statusxp",
    subscriptionNotification: {
      purchaseToken: "private-token",
      notificationType: 12,
    },
  },
  changes = {},
) {
  return new Request("https://test.invalid", {
    method: "POST",
    headers: { authorization: "Bearer test" },
    body: JSON.stringify({
      subscription,
      message: { messageId: "1001", data: btoa(JSON.stringify(payload)) },
      ...changes,
    }),
  });
}
function fixture(changes: Partial<GoogleNotificationDependencies> = {}) {
  const calls: string[] = [];
  const deps: GoogleNotificationDependencies = {
    subscription,
    authenticate: async () => {
      calls.push("auth");
    },
    seen: async () => false,
    lookup: async () => {
      calls.push("lookup");
      return {
        subscriptionKey: `production:${"a".repeat(64)}`,
        linkedSubscriptionKey: null,
        state: "SUBSCRIPTION_STATE_ACTIVE",
        expiresAt: "2026-10-12T00:00:00Z",
        accountId: null,
      };
    },
    apply: async (_id, _hash, _time, value) => {
      calls.push(value?.state ?? "test");
    },
    ...changes,
  };
  return { calls, handle: createGoogleNotificationHandler(deps) };
}
Deno.test("notification type does not replace current Play state", async () => {
  const f = fixture();
  assert.equal((await f.handle(request())).status, 204);
  assert.deepEqual(f.calls, ["auth", "lookup", "SUBSCRIPTION_STATE_ACTIVE"]);
});
Deno.test("authentication and exact PubSub subscription are required before lookups", async () => {
  const f = fixture({
    authenticate: async () => {
      throw new Error("Bad token");
    },
  });
  assert.equal((await f.handle(request())).status, 401);
  assert.deepEqual(f.calls, []);
  const other = fixture();
  assert.equal(
    (await other.handle(request(undefined, { subscription: "wrong" }))).status,
    403,
  );
  assert.deepEqual(other.calls, ["auth"]);
});
Deno.test("duplicate receipts skip provider calls", async () => {
  const f = fixture({ seen: async () => true });
  assert.equal((await f.handle(request())).status, 204);
  assert.deepEqual(f.calls, ["auth"]);
});
Deno.test("provider and commit failures remain retryable", async () => {
  for (
    const changes of [{
      lookup: async () => {
        throw new Error("offline");
      },
    }, {
      apply: async () => {
        throw new Error("database");
      },
    }]
  ) {
    assert.equal((await fixture(changes).handle(request())).status, 503);
  }
});
Deno.test("test notifications commit without querying Play", async () => {
  const f = fixture();
  assert.equal(
    (await f.handle(
      request({
        packageName: "com.statusxp.statusxp",
        testNotification: { version: "1.0" },
      }),
    )).status,
    204,
  );
  assert.deepEqual(f.calls, ["auth", "test"]);
});
Deno.test("malformed, ambiguous and wrong-package payloads cannot mutate access", async () => {
  for (
    const payload of [{}, { packageName: "wrong", testNotification: {} }, {
      packageName: "com.statusxp.statusxp",
      testNotification: {},
      subscriptionNotification: {},
    }]
  ) {
    const f = fixture();
    assert.ok((await f.handle(request(payload))).status >= 400);
    assert.deepEqual(f.calls, ["auth"]);
  }
});
Deno.test("subscription voids reconcile current state and unsupported refunds are not acknowledged", async () => {
  const f = fixture();
  assert.equal(
    (await f.handle(
      request({
        packageName: "com.statusxp.statusxp",
        voidedPurchaseNotification: { productType: 1, purchaseToken: "token" },
      }),
    )).status,
    204,
  );
  assert.equal(
    (await f.handle(
      request({
        packageName: "com.statusxp.statusxp",
        voidedPurchaseNotification: { productType: 2, purchaseToken: "token" },
      }),
    )).status,
    422,
  );
});
Deno.test("body size is bounded", async () => {
  assert.equal(
    (await fixture().handle(
      new Request("https://test.invalid", {
        method: "POST",
        body: "x".repeat(128001),
      }),
    )).status,
    413,
  );
});
Deno.test("snapshot accepts negative states and expired active coverage, rejects unknown data", async () => {
  for (
    const state of [
      "SUBSCRIPTION_STATE_ON_HOLD",
      "SUBSCRIPTION_STATE_PAUSED",
      "SUBSCRIPTION_STATE_EXPIRED",
      "SUBSCRIPTION_STATE_ACTIVE",
      "SUBSCRIPTION_STATE_CANCELED",
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    ]
  ) {
    const result = await parseGoogleSnapshot({
      subscriptionState: state,
      lineItems: [{
        productId: "statusxp_premium_monthly",
        expiryTime: "2020-01-01T00:00:00Z",
      }],
    }, "token");
    assert.equal(result.state, state);
    assert.equal(result.expiresAt, "2020-01-01T00:00:00.000Z");
  }
  for (
    const data of [{}, { subscriptionState: "new-state", lineItems: [] }, {
      subscriptionState: "SUBSCRIPTION_STATE_ACTIVE",
      lineItems: [{ productId: "statusxp_premium_monthly" }],
    }]
  ) {
    await assert.rejects(() => parseGoogleSnapshot(data, "token"));
  }
});
