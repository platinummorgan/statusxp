import { reconcileGoogleSubscription } from "../_shared/google-reconcile.ts";
import { googleTokenKeys } from "../_shared/google-token-vault.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { withAdminAccess } from "../_shared/admin-runtime.ts";
import { reconcileTwitchSubscription } from "../_shared/twitch-reconcile.ts";
import { currentAppleSubscription } from "../_shared/apple-subscription.ts";
import { matchesStoreAccount } from "../_shared/store-identity.ts";
import { runReconciliation } from "./runner.ts";
import { reconcileStripeSubscription } from "./stripe.ts";
import Stripe from "https://esm.sh/stripe@14.10.0?target=deno";
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
const providers: string[] = [];
const stripeKey = Deno.env.get("STRIPE_SECRET_KEY");
const stripe = stripeKey
  ? new Stripe(stripeKey, {
    apiVersion: "2023-10-16",
    httpClient: Stripe.createFetchHttpClient(),
    timeout: 20000,
    maxNetworkRetries: 0,
  })
  : null;
if (stripe) providers.push("stripe");
if (
  ["TWITCH_CLIENT_ID", "TWITCH_BROADCASTER_ID", "TWITCH_BROADCASTER_TOKEN"]
    .every((k) => !!Deno.env.get(k))
) providers.push("twitch");
if (
  [
    "APPLE_APP_STORE_ISSUER_ID",
    "APPLE_APP_STORE_KEY_ID",
    "APPLE_APP_STORE_PRIVATE_KEY",
    "APPLE_APP_STORE_APP_ID",
  ].every((k) => !!Deno.env.get(k))
) providers.push("apple");
if (Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON")) {
  try {
    googleTokenKeys();
    providers.push("google");
  } catch { /* Unconfigured tokens stay queued. */ }
}
Deno.serve(withAdminAccess("POST", async () => {
  if (!providers.length) {
    return new Response("No reconciliation providers configured", {
      status: 503,
    });
  }
  const result = await runReconciliation({
    claim: async () => {
      const { data, error } = await db.rpc("claim_entitlement_reconciliation", {
        p_providers: providers,
        p_include_sandbox:
          Deno.env.get("ENTITLEMENT_RECONCILIATION_SANDBOX") === "true",
      });
      if (error) throw new Error("Reconciliation queue unavailable");
      return data?.[0] ?? null;
    },
    reconcile: async (job) => {
      if (job.provider === "stripe") {
        if (!stripe) throw new Error("Stripe not configured");
        await reconcileStripeSubscription(job, {
          includeSandbox:
            Deno.env.get("ENTITLEMENT_RECONCILIATION_SANDBOX") === "true",
          binding: async (id) => {
            const { data: subscription, error } = await db.from(
              "stripe_subscriptions",
            )
              .select("customer_id").eq("subscription_id", id).maybeSingle();
            if (error) throw new Error("Stripe subscription unavailable");
            if (!subscription) return null;
            const { data: customer, error: customerError } = await db.from(
              "stripe_customers",
            )
              .select("user_id").eq("customer_id", subscription.customer_id)
              .maybeSingle();
            if (customerError) throw new Error("Stripe customer unavailable");
            return customer
              ? {
                customer_id: subscription.customer_id,
                user_id: customer.user_id,
              }
              : null;
          },
          claim: async (event, resource) => {
            const { data, error } = await db.rpc("claim_stripe_event", {
              p_event_id: event,
              p_event_type: "subscription.reconciliation",
              p_resource: resource,
            });
            if (error) throw new Error("Stripe lease unavailable");
            return data;
          },
          retrieve: (id) => stripe.subscriptions.retrieve(id),
          finish: async (event, token, data) => {
            const { error } = await db.rpc("finish_stripe_event", {
              p_event_id: event,
              p_token: token,
              p_data: data,
            });
            if (error) throw new Error("Stripe reconciliation unavailable");
          },
        });
        return;
      }
      if (job.provider === "google") {
        await reconcileGoogleSubscription(db, job.subject, job.user_id);
        return;
      }
      if (job.provider === "twitch") {
        await reconcileTwitchSubscription(job.subject);
        return;
      }
      if (job.provider !== "apple") throw new Error("Unsupported provider");
      const parts = /^(production|sandbox):([0-9]+)$/.exec(job.subject);
      if (!parts) throw new Error("Invalid Apple binding");
      const observedAt = new Date().toISOString();
      const snapshot = await currentAppleSubscription(
        parts[2],
        parts[1] === "sandbox",
      );
      matchesStoreAccount(snapshot.accountToken, job.user_id, true);
      const state = {
        subscriptionKey: snapshot.subscriptionKey,
        status: snapshot.status,
        expiresAt: snapshot.expiresAt,
      };
      const digest = await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(JSON.stringify(state)),
      );
      const { error } = await db.rpc("apply_apple_notification", {
        p_message_id: crypto.randomUUID(),
        p_body_hash: Array.from(
          new Uint8Array(digest),
          (b) => b.toString(16).padStart(2, "0"),
        ).join(""),
        p_observed_at: observedAt,
        p_snapshot: state,
        p_expected_user: job.user_id,
      });
      if (error) throw new Error("Apple reconciliation failed");
    },
    finish: async (job, success) => {
      const { data, error } = await db.rpc(
        "finish_entitlement_reconciliation",
        {
          p_provider: job.provider,
          p_subject: job.subject,
          p_lease: job.lease_token,
          p_success: success,
        },
      );
      if (error) throw new Error("Reconciliation settlement unavailable");
      return data === true;
    },
  });
  return new Response(JSON.stringify({ ...result, providers }), {
    headers: { "Content-Type": "application/json" },
  });
}));
