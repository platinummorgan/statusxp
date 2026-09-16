import assert from "node:assert/strict";
import { createAppleVerifierClient, appleVerifier } from "./apple-verifier.ts";

const secret = "test-apple-verifier-secret-32-characters";
const url = "https://apple-verifier.example.com";
Deno.test("Apple verifier refuses missing configuration and unsafe transport", () => {
  for (const unsafe of ["http://example.com", "https://user:pass@example.com", `${url}/other`, `${url}?query=1`]) {
    assert.throws(() => createAppleVerifierClient(false, { url: unsafe, secret }));
  }
  assert.throws(() => createAppleVerifierClient(false, { url, secret: "short" }));
  const oldUrl = Deno.env.get("APPLE_VERIFIER_URL");
  const oldSecret = Deno.env.get("APPLE_VERIFIER_SECRET");
  try {
    Deno.env.delete("APPLE_VERIFIER_URL");
    Deno.env.delete("APPLE_VERIFIER_SECRET");
    assert.throws(() => appleVerifier(false));
  } finally {
    if (oldUrl !== undefined) Deno.env.set("APPLE_VERIFIER_URL", oldUrl);
    if (oldSecret !== undefined) Deno.env.set("APPLE_VERIFIER_SECRET", oldSecret);
  }
});
Deno.test("Apple verifier authenticates each payload kind and binds the requested environment", async () => {
  for (const sandbox of [true, false]) {
    const calls: string[] = [];
    const client = createAppleVerifierClient(sandbox, { url, secret, fetcher: async (input, init) => {
      assert.equal(input, `${url}/verify`);
      assert.equal(init?.redirect, "error");
      assert.equal(new Headers(init?.headers).get("Authorization"), `Bearer ${secret}`);
      const body = JSON.parse(init?.body as string);
      assert.equal(body.sandbox, sandbox);
      assert.equal(body.signedPayload, "signed");
      calls.push(body.kind);
      return Response.json({ payload: { verified: true } });
    } });
    assert.deepEqual(await client.verifyAndDecodeNotification("signed"), { verified: true });
    await client.verifyAndDecodeTransaction("signed");
    await client.verifyAndDecodeRenewalInfo("signed");
    assert.deepEqual(calls, ["notification", "transaction", "renewal"]);
  }
});
Deno.test("Apple verifier never accepts a failed, malformed or unavailable verification response", async () => {
  for (const response of [new Response("private data", { status: 401 }), new Response("private data", { status: 422 }), new Response("unavailable", { status: 503 }), Response.json({}), Response.json({ payload: [] })]) {
    const client = createAppleVerifierClient(false, { url, secret, fetcher: async () => response });
    await assert.rejects(() => client.verifyAndDecodeNotification("signed"));
  }
  const client = createAppleVerifierClient(false, { url, secret, fetcher: async () => { throw new Error("timeout"); } });
  await assert.rejects(() => client.verifyAndDecodeNotification("signed"));
});
