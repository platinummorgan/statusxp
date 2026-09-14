import assert from "node:assert/strict";
import {
  applyGoogleSnapshot,
  reconcileGoogleSubscription,
} from "./google-reconcile.ts";
import { googleSubscriptionKey } from "./store-identity.ts";
import { openGoogleToken, sealGoogleToken } from "./google-token-vault.ts";
const token = "private-google-token";
const subscriptionKey = await googleSubscriptionKey(token, false);
const user = "00000000-0000-4000-8000-000000000001";
const snapshot = {
  subscriptionKey,
  linkedSubscriptionKey: null,
  state: "SUBSCRIPTION_STATE_ON_HOLD",
  expiresAt: "2026-10-01T00:00:00Z",
  accountId: null,
};
function database(
  bindings: unknown[] = [{ subscription_key: subscriptionKey, user_id: user }],
) {
  const calls: { name: string; args: any }[] = [];
  const db: any = {
    from: () => ({
      select: () => ({
        eq: () => ({ in: async () => ({ data: bindings, error: null }) }),
      }),
    }),
    rpc: async (name: string, args: any) => {
      calls.push({ name, args });
      return { error: null };
    },
  };
  return { db, calls };
}
Deno.test("known-owner reconciliation sends ciphertext only through the atomic RPC", async () => {
  const saved = Deno.env.get("GOOGLE_PLAY_TOKEN_KEYS"),
    active = Deno.env.get("GOOGLE_PLAY_TOKEN_ACTIVE_KEY");
  try {
    Deno.env.set(
      "GOOGLE_PLAY_TOKEN_KEYS",
      JSON.stringify({ test: btoa("k".repeat(32)) }),
    );
    Deno.env.set("GOOGLE_PLAY_TOKEN_ACTIVE_KEY", "test");
    const { db, calls } = database();
    await applyGoogleSnapshot(
      db,
      "123",
      "a".repeat(64),
      new Date().toISOString(),
      snapshot,
      token,
      user,
    );
    assert.equal(calls[0].name, "apply_google_notification_with_token");
    assert.equal(JSON.stringify(calls).includes(token), false);
    assert.equal(
      await openGoogleToken(calls[0].args.p_token_envelope, subscriptionKey),
      token,
    );
    assert.equal(calls[0].args.p_expected_user, user);
    assert.equal(calls[0].args.p_snapshot.state, snapshot.state);
  } finally {
    if (saved === undefined) Deno.env.delete("GOOGLE_PLAY_TOKEN_KEYS");
    else Deno.env.set("GOOGLE_PLAY_TOKEN_KEYS", saved);
    if (active === undefined) Deno.env.delete("GOOGLE_PLAY_TOKEN_ACTIVE_KEY");
    else Deno.env.set("GOOGLE_PLAY_TOKEN_ACTIVE_KEY", active);
  }
});
Deno.test("unbound notices do not retain tokens; account tombstones do not use predecessor owners", async () => {
  for (
    const rows of [[], [{ subscription_key: subscriptionKey, user_id: null }, {
      subscription_key: "old",
      user_id: user,
    }]]
  ) {
    const { db, calls } = database(rows);
    await applyGoogleSnapshot(
      db,
      "123",
      "a".repeat(64),
      new Date().toISOString(),
      snapshot,
      token,
    );
    assert.equal(calls[0].args.p_token_envelope, null);
    assert.equal(calls[0].args.p_expected_user, null);
  }
});
Deno.test("scheduler owner changes and mismatched store account claims fail before persistence", async () => {
  const { db, calls } = database();
  await assert.rejects(
    () =>
      applyGoogleSnapshot(
        db,
        "123",
        "a".repeat(64),
        new Date().toISOString(),
        snapshot,
        token,
        "another-user",
      ),
    /Binding changed/,
  );
  await assert.rejects(
    () =>
      applyGoogleSnapshot(db, "123", "a".repeat(64), new Date().toISOString(), {
        ...snapshot,
        accountId: "wrong",
      }, token),
    /another account/,
  );
  assert.equal(calls.length, 0);
});
Deno.test("scheduled Google checks decrypt only for lookup and fail without applying uncertain state", async () => {
  const saved = Deno.env.get("GOOGLE_PLAY_TOKEN_KEYS"),
    active = Deno.env.get("GOOGLE_PLAY_TOKEN_ACTIVE_KEY");
  try {
    Deno.env.set(
      "GOOGLE_PLAY_TOKEN_KEYS",
      JSON.stringify({ test: btoa("k".repeat(32)) }),
    );
    Deno.env.set("GOOGLE_PLAY_TOKEN_ACTIVE_KEY", "test");
    const envelope = await sealGoogleToken(token, subscriptionKey);
    const { db, calls } = database();
    const originalFrom = db.from;
    db.from = (name: string) =>
      name === "google_play_tokens"
        ? {
          select: () => ({
            eq: () => ({
              eq: () => ({
                maybeSingle: async () => ({ data: { envelope }, error: null }),
              }),
            }),
          }),
        }
        : originalFrom(name);
    let lookups = 0;
    await reconcileGoogleSubscription(
      db,
      subscriptionKey,
      user,
      async (path) => {
        lookups++;
        assert.equal(
          path.endsWith(`/tokens/${encodeURIComponent(token)}`),
          true,
        );
        return {
          subscriptionState: "SUBSCRIPTION_STATE_ON_HOLD",
          lineItems: [{
            productId: "statusxp_premium_monthly",
            expiryTime: snapshot.expiresAt,
          }],
        };
      },
    );
    assert.equal(lookups, 1);
    assert.equal(calls.length, 1);
    assert.equal(calls[0].args.p_snapshot.state, "SUBSCRIPTION_STATE_ON_HOLD");
    assert.match(calls[0].args.p_message_id, /^[0-9]{1,100}$/);
    await assert.rejects(() =>
      reconcileGoogleSubscription(db, subscriptionKey, user, async () => {
        throw new Error("Provider unavailable");
      })
    );
    await assert.rejects(
      () =>
        reconcileGoogleSubscription(
          db,
          subscriptionKey,
          user,
          async () => ({
            testPurchase: {},
            subscriptionState: "SUBSCRIPTION_STATE_ON_HOLD",
            lineItems: [{
              productId: "statusxp_premium_monthly",
              expiryTime: snapshot.expiresAt,
            }],
          }),
        ),
      /environment changed/,
    );
    envelope.ciphertext = "broken";
    await assert.rejects(
      () =>
        reconcileGoogleSubscription(db, subscriptionKey, user, async () => {
          throw new Error("Must not reach provider");
        }),
      /Unable to open/,
    );
    assert.equal(calls.length, 1);
  } finally {
    if (saved === undefined) Deno.env.delete("GOOGLE_PLAY_TOKEN_KEYS");
    else Deno.env.set("GOOGLE_PLAY_TOKEN_KEYS", saved);
    if (active === undefined) Deno.env.delete("GOOGLE_PLAY_TOKEN_ACTIVE_KEY");
    else Deno.env.set("GOOGLE_PLAY_TOKEN_ACTIVE_KEY", active);
  }
});
