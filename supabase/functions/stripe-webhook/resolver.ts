import type Stripe from "https://esm.sh/stripe@14.10.0?target=deno";
import type { Event } from "./handler.ts";
export type StripeLookup = {
  checkout: (id: string) => Promise<Stripe.Checkout.Session>;
  subscription: (id: string) => Promise<Stripe.Subscription>;
};
function id(value: string | { id: string } | null): string {
  if (!value) throw new Error("Missing Stripe identity");
  return typeof value === "string" ? value : value.id;
}
export async function subscriptionData(
  subscriptionId: string,
  api: Pick<StripeLookup, "subscription">,
  expectedUser?: string | null,
) {
  const sub = await api.subscription(subscriptionId);
  const price = sub.items.data[0]?.price;
  if (
    sub.items.data.length !== 1 || sub.items.data[0].quantity !== 1 ||
    price?.currency !== "usd" || price.unit_amount !== 499 ||
    price.recurring?.interval !== "month" ||
    price.recurring.interval_count !== 1
  ) throw new Error("Unknown subscription product");
  if (
    expectedUser && sub.metadata.user_id &&
    expectedUser !== sub.metadata.user_id
  ) throw new Error("Binding conflict");
  return {
    kind: "subscription",
    subscription_id: sub.id,
    customer_id: id(sub.customer),
    user_id: expectedUser || sub.metadata.user_id || null,
    status: sub.status,
    expires_at: new Date(sub.current_period_end * 1000).toISOString(),
  };
}
export async function resolveStripeEvent(
  event: Event,
  api: StripeLookup,
): Promise<Record<string, unknown>> {
  if (
    [
      "customer.subscription.created",
      "customer.subscription.updated",
      "customer.subscription.deleted",
    ].includes(event.type)
  ) {
    return await subscriptionData(event.data.object.id, api);
  }
  if (
    ["checkout.session.completed", "checkout.session.async_payment_succeeded"]
      .includes(event.type)
  ) {
    const session = await api.checkout(
      event.data.object.id,
    );
    if (session.mode === "subscription") {
      return await subscriptionData(
        id(session.subscription),
        api,
        session.client_reference_id || session.metadata?.user_id,
      );
    }
    if (session.mode !== "payment" || session.payment_status !== "paid") {
      return { kind: "ignored" };
    }
    return {
      kind: "pack",
      session_id: session.id,
      customer_id: id(session.customer),
      user_id: session.client_reference_id || session.metadata?.user_id ||
        null,
      payment_intent: id(session.payment_intent),
      pack_type: session.metadata?.pack_type,
      amount: session.amount_total,
      currency: session.currency,
    };
  }
  return { kind: "ignored" };
}
