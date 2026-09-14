import assert from "node:assert/strict";
import {
  createLocalJWKSet,
  exportJWK,
  generateKeyPair,
  SignJWT,
} from "npm:jose@6.1.0";
import { googlePushAuth } from "./auth.ts";
Deno.test("real RSA signatures, audience, issuer, service identity and expiry are verified", async () => {
  const { privateKey, publicKey } = await generateKeyPair("RS256");
  const keys = createLocalJWKSet({
    keys: [{ ...await exportJWK(publicKey), kid: "test" }],
  });
  const auth = googlePushAuth(
    "push@test.iam.gserviceaccount.com",
    "https://test.invalid/push",
    keys,
  );
  const now = Math.floor(Date.now() / 1000);
  const claims = {
    iss: "https://accounts.google.com",
    aud: "https://test.invalid/push",
    sub: "123",
    iat: now,
    exp: now + 3600,
    email: "push@test.iam.gserviceaccount.com",
    email_verified: true,
  };
  const sign = (overrides = {}) =>
    new SignJWT({ ...claims, ...overrides }).setProtectedHeader({
      alg: "RS256",
      kid: "test",
    }).sign(privateKey);
  await auth(`Bearer ${await sign()}`);
  for (
    const changes of [{ aud: "wrong" }, { iss: "wrong" }, { email: "wrong" }, {
      email_verified: false,
    }, { exp: now - 60 }]
  ) {
    await assert.rejects(() =>
      sign(changes).then((token) => auth(`Bearer ${token}`))
    );
  }
  const token = await sign();
  const parts = token.split(".");
  parts[1] = btoa(JSON.stringify({ ...claims, email: "attacker" })).replace(
    /=/g,
    "",
  );
  await assert.rejects(() => auth(`Bearer ${parts.join(".")}`));
  await assert.rejects(() => auth(null));
});
