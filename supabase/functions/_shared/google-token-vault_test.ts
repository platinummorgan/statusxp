import assert from "node:assert/strict";
import { googleSubscriptionKey } from "./store-identity.ts";
import {
  googleTokenKeys,
  openGoogleToken,
  sealGoogleToken,
} from "./google-token-vault.ts";
const old = btoa("a".repeat(32)), next = btoa("b".repeat(32));
const config = { active: "old", keys: { old } };
const token = "private-purchase-token";
const subject = await googleSubscriptionKey(token, false);
Deno.test("token encryption randomizes ciphertext and round trips without plaintext fields", async () => {
  const a = await sealGoogleToken(token, subject, config);
  const b = await sealGoogleToken(token, subject, config);
  assert.notEqual(a.iv, b.iv);
  assert.notEqual(a.ciphertext, b.ciphertext);
  assert.equal(JSON.stringify(a).includes(token), false);
  assert.equal(await openGoogleToken(a, subject, config), token);
});
Deno.test("token ciphertext rejects tampering, wrong identity, and wrong keys", async () => {
  const a = await sealGoogleToken(token, subject, config);
  await assert.rejects(() =>
    openGoogleToken(
      {
        ...a,
        ciphertext: (a.ciphertext[0] === "A" ? "B" : "A") +
          a.ciphertext.slice(1),
      },
      subject,
      config,
    )
  );
  await assert.rejects(() =>
    openGoogleToken(a, subject.replace("production:", "sandbox:"), config)
  );
  await assert.rejects(() =>
    openGoogleToken(a, subject, { active: "old", keys: { old: next } })
  );
  await assert.rejects(() => sealGoogleToken("different", subject, config));
  await assert.rejects(() =>
    openGoogleToken({ ...a, version: 2 } as never, subject, config)
  );
});
Deno.test("key rotation reads retained keys and writes the active key", async () => {
  const a = await sealGoogleToken(token, subject, config);
  const rotated = { active: "next", keys: { old, next } };
  assert.equal(await openGoogleToken(a, subject, rotated), token);
  const b = await sealGoogleToken(token, subject, rotated);
  assert.equal(b.keyId, "next");
  await assert.rejects(() =>
    openGoogleToken(a, subject, { active: "next", keys: { next } })
  );
});
Deno.test("missing and invalid encryption configuration fails closed with redacted errors", () => {
  const saved = Deno.env.get("GOOGLE_PLAY_TOKEN_KEYS");
  const active = Deno.env.get("GOOGLE_PLAY_TOKEN_ACTIVE_KEY");
  try {
    Deno.env.delete("GOOGLE_PLAY_TOKEN_KEYS");
    assert.throws(() => googleTokenKeys(), /not configured/);
    Deno.env.set(
      "GOOGLE_PLAY_TOKEN_KEYS",
      JSON.stringify({ old: "secret-invalid-key" }),
    );
    Deno.env.set("GOOGLE_PLAY_TOKEN_ACTIVE_KEY", "old");
    assert.throws(
      () => googleTokenKeys(),
      /^Error: Google token encryption is not configured$/,
    );
  } finally {
    if (saved === undefined) Deno.env.delete("GOOGLE_PLAY_TOKEN_KEYS");
    else Deno.env.set("GOOGLE_PLAY_TOKEN_KEYS", saved);
    if (active === undefined) Deno.env.delete("GOOGLE_PLAY_TOKEN_ACTIVE_KEY");
    else Deno.env.set("GOOGLE_PLAY_TOKEN_ACTIVE_KEY", active);
  }
});
