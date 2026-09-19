import type Stripe from "https://esm.sh/stripe@14.10.0?target=deno";
import { subscriptionData } from "../stripe-webhook/resolver.ts";
import type { ReconciliationJob } from "./runner.ts";

export type StripeReconciliationDependencies = {
  binding: (
    subscription: string,
  ) => Promise<{ customer_id: string; user_id: string | null } | null>;
  claim: (
    event: string,
    resource: string,
  ) => Promise<{ state: string; token?: string }>;
  retrieve: (subscription: string) => Promise<Stripe.Subscription>;
  finish: (
    event: string,
    token: string,
    data: Record<string, unknown>,
  ) => Promise<void>;
  includeSandbox?: boolean;
};

export async function reconcileStripeSubscription(
  job: ReconciliationJob,
  deps: StripeReconciliationDependencies,
) {
  if (job.provider !== "stripe" || !/^sub_[A-Za-z0-9]+$/.test(job.subject)) {
    throw new Error("Invalid Stripe job");
  }
  const binding = await deps.binding(job.subject);
  if (!binding || binding.user_id !== job.user_id) {
    throw new Error("Stripe binding changed");
  }
  // Share the webhook's resource lease before fetching current provider state.
  const event = `reconcile_stripe_${job.lease_token}`;
  const claim = await deps.claim(event, `subscription:${job.subject}`);
  if (claim.state === "done") return;
  if (claim.state !== "claimed" || !claim.token) {
    throw new Error("Stripe resource busy");
  }
  const data = await subscriptionData(job.subject, {
    subscription: async (id) => {
      const sub = await deps.retrieve(id);
      const customer = typeof sub.customer === "string"
        ? sub.customer
        : sub.customer?.id;
      if (sub.id !== id || customer !== binding.customer_id) {
        throw new Error("Stripe resource mismatch");
      }
      if (
        sub.livemode !== true &&
        !(deps.includeSandbox && sub.livemode === false)
      ) throw new Error("Stripe environment mismatch");
      if (
        ![
          "active",
          "trialing",
          "past_due",
          "unpaid",
          "incomplete",
          "incomplete_expired",
          "canceled",
          "paused",
        ].includes(sub.status) ||
        !Number.isFinite(sub.current_period_end) || sub.current_period_end <= 0
      ) throw new Error("Invalid Stripe state");
      return sub;
    },
  }, job.user_id);
  await deps.finish(event, claim.token, data);
}
