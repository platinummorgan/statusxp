import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { currentAppleSubscription } from "../_shared/apple-subscription.ts";
import { matchesStoreAccount } from "../_shared/store-identity.ts";
import { verifyAppleNotice } from "./auth.ts";
import { createAppleHandler } from "./handler.ts";
const db = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  { auth: { persistSession: false } },
);
Deno.serve(createAppleHandler({
  verify: verifyAppleNotice,
  lookup: currentAppleSubscription,
  seen: async (id, hash) => {
    const { data, error } = await db.from("apple_notification_receipts").select(
      "body_hash",
    ).eq("message_id", id).maybeSingle();
    if (error || (data && data.body_hash !== hash)) {
      throw new Error("Receipt unavailable");
    }
    return !!data;
  },
  apply: async (id, hash, observedAt, snapshot) => {
    let owner: string | null = null;
    if (snapshot) {
      const { data, error } = await db.from("store_subscription_bindings")
        .select("user_id").eq("platform", "app_store")
        .eq("subscription_key", snapshot.subscriptionKey).maybeSingle();
      if (error) throw new Error("Binding unavailable");
      owner = data?.user_id ?? null;
      if (owner) matchesStoreAccount(snapshot.accountToken, owner, true);
    }
    const { error } = await db.rpc("apply_apple_notification", {
      p_message_id: id,
      p_body_hash: hash,
      p_observed_at: observedAt,
      p_expected_user: owner,
      p_snapshot: snapshot
        ? {
          subscriptionKey: snapshot.subscriptionKey,
          status: snapshot.status,
          expiresAt: snapshot.expiresAt,
        }
        : null,
    });
    if (error) throw new Error("Reconciliation unavailable");
  },
}));
