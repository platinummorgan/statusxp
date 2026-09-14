import assert from "node:assert/strict";
import type Stripe from "https://esm.sh/stripe@14.10.0?target=deno";
import {
  reconcileStripeSubscription,
  type StripeReconciliationDependencies,
} from "./stripe.ts";
import type { ReconciliationJob } from "./runner.ts";
const job: ReconciliationJob = {
  provider: "stripe",
  subject: "sub_test",
  user_id: "owner",
  lease_token: "queue-lease",
};
const subscription = {
  id: "sub_test",
  customer: "cus_test",
  metadata: {},
  livemode: true,
  status: "active",
  current_period_end: 1800000000,
  items: {
    data: [{
      quantity: 1,
      price: {
        currency: "usd",
        unit_amount: 499,
        recurring: { interval: "month", interval_count: 1 },
      },
    }],
  },
} as unknown as Stripe.Subscription;
function fixture(changes: Partial<StripeReconciliationDependencies> = {}) {
  const calls: string[] = [];
  let applied: Record<string, unknown> | undefined;
  const deps: StripeReconciliationDependencies = {
    binding: async () => {
      calls.push("binding");
      return { customer_id: "cus_test", user_id: "owner" };
    },
    claim: async (event, resource) => {
      assert.equal(event, "reconcile_stripe_queue-lease");
      assert.equal(resource, "subscription:sub_test");
      calls.push("claim");
      return { state: "claimed", token: "stripe-lease" };
    },
    retrieve: async () => {
      calls.push("retrieve");
      return subscription;
    },
    finish: async (event, token, data) => {
      assert.equal(event, "reconcile_stripe_queue-lease");
      assert.equal(token, "stripe-lease");
      calls.push("finish");
      applied = data;
    },
    ...changes,
  };
  return { calls, deps, applied: () => applied };
}
Deno.test("Stripe scheduling acquires the webhook resource lease before lookup and pins the owner", async () => {
  const f = fixture();
  await reconcileStripeSubscription(job, f.deps);
  assert.deepEqual(f.calls, ["binding", "claim", "retrieve", "finish"]);
  assert.equal(f.applied()?.user_id, "owner");
  assert.equal(f.applied()?.expires_at, new Date(1800000000000).toISOString());
});
Deno.test("busy resources and completed attempts never fetch Stripe", async () => {
  const busy = fixture({ claim: async () => ({ state: "busy" }) });
  await assert.rejects(
    () => reconcileStripeSubscription(job, busy.deps),
    /busy/,
  );
  assert.deepEqual(busy.calls, ["binding"]);
  const done = fixture({ claim: async () => ({ state: "done" }) });
  await reconcileStripeSubscription(job, done.deps);
  assert.deepEqual(done.calls, ["binding"]);
});
Deno.test("deleted or changed owners fail before acquiring a Stripe lease", async () => {
  for (
    const binding of [null, { customer_id: "cus_test", user_id: null }, {
      customer_id: "cus_test",
      user_id: "other",
    }]
  ) {
    const f = fixture({ binding: async () => binding });
    await assert.rejects(
      () => reconcileStripeSubscription(job, f.deps),
      /binding changed/,
    );
    assert.deepEqual(f.calls, []);
  }
});
Deno.test("Stripe identity, account metadata, product, and malformed state are rejected", async () => {
  for (
    const changes of [
      { id: "sub_other" },
      { customer: "cus_other" },
      { metadata: { user_id: "other" } },
      { items: { data: [] } },
      { status: "unknown" },
      { current_period_end: NaN },
    ]
  ) {
    const f = fixture({
      retrieve: async () =>
        ({ ...subscription, ...changes }) as Stripe.Subscription,
    });
    await assert.rejects(() => reconcileStripeSubscription(job, f.deps));
    assert.equal(f.applied(), undefined);
  }
});
Deno.test("Stripe test mode requires explicit opt-in", async () => {
  const retrieve = async () => ({ ...subscription, livemode: false });
  await assert.rejects(
    () => reconcileStripeSubscription(job, fixture({ retrieve }).deps),
    /environment mismatch/,
  );
  const f = fixture({ retrieve, includeSandbox: true });
  await reconcileStripeSubscription(job, f.deps);
  assert.equal(f.applied()?.status, "active");
});
Deno.test("negative current state is applied; lookup and settlement failures propagate for retry", async () => {
  const f = fixture({
    retrieve: async () => ({ ...subscription, status: "canceled" }),
  });
  await reconcileStripeSubscription(job, f.deps);
  assert.equal(f.applied()?.status, "canceled");
  const failed = fixture({
    retrieve: async () => {
      throw new Error("Provider unavailable");
    },
  });
  await assert.rejects(
    () => reconcileStripeSubscription(job, failed.deps),
    /Provider unavailable/,
  );
  assert.equal(failed.applied(), undefined);
  await assert.rejects(
    () =>
      reconcileStripeSubscription(
        job,
        fixture({
          finish: async () => {
            throw new Error("Database unavailable");
          },
        }).deps,
      ),
    /Database unavailable/,
  );
});
