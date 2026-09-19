import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import { matchesStoreAccount } from "./store-identity.ts";
import { openGoogleToken, sealGoogleToken } from "./google-token-vault.ts";
import { googleGet } from "./google-play.ts";
import {
  type GoogleSnapshot,
  packageId,
  parseGoogleSnapshot,
} from "../google-play-notifications/snapshot.ts";

export async function applyGoogleSnapshot(
  db: SupabaseClient,
  id: string,
  hash: string,
  observedAt: string,
  snapshot: GoogleSnapshot | null,
  token: string | null,
  expectedOwner?: string,
) {
  let owner: string | null = null;
  if (snapshot) {
    const keys = [snapshot.subscriptionKey, snapshot.linkedSubscriptionKey]
      .filter((k): k is string => !!k);
    const { data, error } = await db.from("store_subscription_bindings")
      .select("subscription_key,user_id").eq("platform", "google_play").in(
        "subscription_key",
        keys,
      );
    if (error) throw new Error("Binding unavailable");
    const current = data?.find((b) =>
      b.subscription_key === snapshot.subscriptionKey
    );
    owner = current ? current.user_id : data?.[0]?.user_id ?? null;
    if (owner) {
      const digest = await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(owner),
      );
      const expected = Array.from(
        new Uint8Array(digest),
        (b) => b.toString(16).padStart(2, "0"),
      ).join("");
      matchesStoreAccount(snapshot.accountId, expected);
    }
  }
  if (expectedOwner !== undefined && owner !== expectedOwner) {
    throw new Error("Binding changed");
  }
  const { error } = await db.rpc("apply_google_notification_with_token", {
    p_message_id: id,
    p_body_hash: hash,
    p_observed_at: observedAt,
    p_snapshot: snapshot
      ? {
        subscriptionKey: snapshot.subscriptionKey,
        linkedSubscriptionKey: snapshot.linkedSubscriptionKey,
        state: snapshot.state,
        expiresAt: snapshot.expiresAt,
      }
      : null,
    p_expected_user: owner,
    p_token_envelope: snapshot && owner
      ? await sealGoogleToken(token!, snapshot.subscriptionKey)
      : null,
  });
  if (error) throw new Error("Reconciliation unavailable");
}
export async function reconcileGoogleSubscription(
  db: SupabaseClient,
  subject: string,
  owner: string,
  lookup: typeof googleGet = googleGet,
) {
  const { data, error } = await db.from("google_play_tokens").select("envelope")
    .eq("subscription_key", subject).eq("user_id", owner).maybeSingle();
  if (error || !data) throw new Error("Google token unavailable");
  const token = await openGoogleToken(data.envelope, subject);
  const observedAt = new Date().toISOString();
  const snapshot = await parseGoogleSnapshot(
    await lookup(
      `/androidpublisher/v3/applications/${packageId}/purchases/subscriptionsv2/tokens/${
        encodeURIComponent(token)
      }`,
    ),
    token,
  );
  if (snapshot.subscriptionKey !== subject) {
    throw new Error("Google environment changed");
  }
  // Numeric receipt IDs are compatible with Pub/Sub; 128 random bits avoid reuse.
  const id = BigInt(`0x${crypto.randomUUID().replaceAll("-", "")}`).toString();
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(
      JSON.stringify({
        subscriptionKey: snapshot.subscriptionKey,
        state: snapshot.state,
        expiresAt: snapshot.expiresAt,
        linkedSubscriptionKey: snapshot.linkedSubscriptionKey,
      }),
    ),
  );
  const hash = Array.from(
    new Uint8Array(digest),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
  await applyGoogleSnapshot(db, id, hash, observedAt, snapshot, token, owner);
}
