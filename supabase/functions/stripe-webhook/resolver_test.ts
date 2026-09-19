import assert from "node:assert/strict";
import type Stripe from "https://esm.sh/stripe@14.10.0?target=deno";
import { resolveStripeEvent, type StripeLookup } from "./resolver.ts";
import type { Event } from "./handler.ts";
const subscription = {
  id: "sub_test",
  customer: "cus_test",
  metadata: { user_id: "user" },
  status: "canceled",
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
const session = {
  id: "cs_test",
  mode: "payment",
  customer: "cus_test",
  client_reference_id: "user",
  metadata: { pack_type: "small", credits: "999999" },
  payment_status: "paid",
  payment_intent: "pi_test",
  amount_total: 199,
  currency: "usd",
} as Stripe.Checkout.Session;
const event = (type: string): Event => ({
  id: "evt_test",
  type,
  data: { object: { id: "object_test" } },
});
const api: StripeLookup = {
  checkout: async () => session,
  subscription: async () => subscription,
};
Deno.test("reordered subscription events use current Stripe state, not historical type", async () => {
  for (
    const type of [
      "customer.subscription.created",
      "customer.subscription.updated",
      "customer.subscription.deleted",
    ]
  ) {
    const result = await resolveStripeEvent(event(type), api);
    assert.equal(result.status, "canceled");
    assert.equal(result.customer_id, "cus_test");
  }
});
Deno.test("unpaid checkout does not grant credits; async success resolves paid state", async () => {
  const unpaid = await resolveStripeEvent(event("checkout.session.completed"), {
    ...api,
    checkout: async () => ({ ...session, payment_status: "unpaid" }),
  });
  assert.equal(unpaid.kind, "ignored");
  const paid = await resolveStripeEvent(
    event("checkout.session.async_payment_succeeded"),
    api,
  );
  assert.equal(paid.kind, "pack");
  assert.equal(paid.amount, 199);
  assert.equal(paid.credits, undefined);
});
Deno.test("subscription checkout rejects conflicting account metadata", async () => {
  await assert.rejects(
    () =>
      resolveStripeEvent(event("checkout.session.completed"), {
        ...api,
        checkout: async () => ({
          ...session,
          mode: "subscription",
          subscription: "sub_test",
          client_reference_id: "other-user",
        }),
      }),
    /Binding conflict/,
  );
});
Deno.test("unknown recurring product never grants premium", async () => {
  await assert.rejects(
    () =>
      resolveStripeEvent(event("customer.subscription.updated"), {
        ...api,
        subscription: async () => ({
          ...subscription,
          items: { ...subscription.items, data: [] },
        }),
      }),
    /Unknown subscription product/,
  );
});
