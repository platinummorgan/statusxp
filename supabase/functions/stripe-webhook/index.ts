import { resolveStripeEvent } from "./resolver.ts";
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import Stripe from "https://esm.sh/stripe@14.10.0?target=deno";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
import { createStripeWebhook } from "./handler.ts";
const stripe = new Stripe(Deno.env.get("STRIPE_SECRET_KEY") || "", {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
  timeout: 20000,
  maxNetworkRetries: 1,
});
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
async function rpc(name: string, args: Record<string, unknown>) {
  const { data, error } = await db.rpc(name, args);
  if (error) throw new Error("Database unavailable");
  return data;
}
serve(createStripeWebhook({
  verify: async (body, signature) => {
    const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET");
    if (!secret) throw new Error("Webhook not configured");
    return await stripe.webhooks.constructEventAsync(
      body,
      signature,
      secret,
      undefined,
      Stripe.createSubtleCryptoProvider(),
    );
  },
  claim: (event, resource) =>
    rpc("claim_stripe_event", {
      p_event_id: event.id,
      p_event_type: event.type,
      p_resource: resource,
    }),
  resolve: (event) =>
    resolveStripeEvent(event, {
      checkout: (id) => stripe.checkout.sessions.retrieve(id),
      subscription: (id) => stripe.subscriptions.retrieve(id),
    }),
  finish: async (eventId, token, data) => {
    await rpc("finish_stripe_event", {
      p_event_id: eventId,
      p_token: token,
      p_data: data,
    });
  },
}));
