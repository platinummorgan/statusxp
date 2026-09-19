import assert from "node:assert/strict";
import {
  createStripeWebhook,
  type Event,
  type WebhookDependencies,
} from "./handler.ts";
const event: Event = {
  id: "evt_1",
  type: "customer.subscription.updated",
  data: { object: { id: "sub_1" } },
};
function fixture(overrides: Partial<WebhookDependencies> = {}) {
  const calls: string[] = [];
  const handler = createStripeWebhook({
    verify: async () => event,
    claim: async (e, resource) => {
      assert.equal(e.id, "evt_1");
      assert.equal(resource, "subscription:sub_1");
      calls.push("claim");
      return { state: "claimed", token: "lease" };
    },
    resolve: async () => {
      calls.push("fetch-current");
      return { kind: "subscription" };
    },
    finish: async () => {
      calls.push("commit");
    },
    ...overrides,
  });
  return {
    calls,
    request: () =>
      handler(
        new Request("https://local/webhook", {
          method: "POST",
          headers: { "stripe-signature": "signature" },
          body: "{}",
        }),
      ),
    handler,
  };
}
Deno.test("acknowledges only after current state and durable commit", async () => {
  const f = fixture();
  assert.equal((await f.request()).status, 200);
  assert.deepEqual(f.calls, ["claim", "fetch-current", "commit"]);
});
Deno.test("invalid signature never claims or fulfills", async () => {
  const f = fixture({
    verify: async () => {
      throw new Error("invalid");
    },
  });
  assert.equal((await f.request()).status, 400);
  assert.deepEqual(f.calls, []);
});
Deno.test("busy resource rejects delivery for retry without fetching stale state", async () => {
  const f = fixture({ claim: async () => ({ state: "busy" }) });
  assert.equal((await f.request()).status, 503);
  assert.deepEqual(f.calls, []);
});
Deno.test("committed duplicate acknowledges without repeating fulfillment", async () => {
  const f = fixture({ claim: async () => ({ state: "done" }) });
  assert.equal((await f.request()).status, 200);
  assert.deepEqual(f.calls, []);
});
Deno.test("Stripe or database outage is retryable and does not expose details", async () => {
  for (
    const overrides of [
      {
        claim: async () => {
          throw new Error("db secret");
        },
      },
      {
        resolve: async () => {
          throw new Error("Stripe secret");
        },
      },
      {
        finish: async () => {
          throw new Error("db secret");
        },
      },
    ]
  ) {
    const f = fixture(overrides);
    const response = await f.request();
    assert.equal(response.status, 503);
    assert.ok(!(await response.text()).includes("secret"));
  }
});
Deno.test("timeout after commit replays safely", async () => {
  let done = false, fulfillments = 0;
  const f = fixture({
    claim: async () =>
      done ? { state: "done" } : { state: "claimed", token: "lease" },
    finish: async () => {
      done = true;
      fulfillments++;
      throw new Error("Lost response");
    },
  });
  assert.equal((await f.request()).status, 503);
  assert.equal((await f.request()).status, 200);
  assert.equal(fulfillments, 1);
});
Deno.test("checkout and subscription events share a subscription lease", async () => {
  const checkout: Event = {
    id: "evt_1",
    type: "checkout.session.completed",
    data: {
      object: { id: "cs_1", mode: "subscription", subscription: "sub_1" },
    },
  };
  const f = fixture({ verify: async () => checkout });
  assert.equal((await f.request()).status, 200);
});
Deno.test("oversized payload stops before signature processing", async () => {
  const f = fixture({
    verify: async () => {
      throw new Error("Must not verify");
    },
  });
  const response = await f.handler(
    new Request("https://local/webhook", {
      method: "POST",
      headers: { "stripe-signature": "signature" },
      body: "x".repeat(512001),
    }),
  );
  assert.equal(response.status, 413);
});
