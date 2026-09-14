import assert from "node:assert/strict";
import Stripe from "https://esm.sh/stripe@14.10.0?target=deno";
const stripe = new Stripe("sk_test_fixture_only", {
  apiVersion: "2023-10-16",
  httpClient: Stripe.createFetchHttpClient(),
});
Deno.test("real Stripe signature verification accepts intact bytes and rejects tampering", async () => {
  const secret = "whsec_local_fixture_only";
  const body = JSON.stringify({
    id: "evt_fixture",
    type: "checkout.session.completed",
    data: { object: { id: "cs_fixture" } },
  });
  const timestamp = Math.floor(Date.now() / 1000);
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(`${timestamp}.${body}`),
  );
  const hex = Array.from(
    new Uint8Array(digest),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
  const signature = `t=${timestamp},v1=${hex}`;
  const verify = (raw: string) =>
    stripe.webhooks.constructEventAsync(
      raw,
      signature,
      secret,
      undefined,
      Stripe.createSubtleCryptoProvider(),
    );
  assert.equal((await verify(body)).id, "evt_fixture");
  await assert.rejects(() => verify(body.replace("cs_fixture", "cs_tampered")));
});
