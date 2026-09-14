import assert from "node:assert/strict";
import { X509Certificate } from "node:crypto";
import { Buffer } from "node:buffer";
import { generateKeyPair, SignJWT } from "npm:jose@6.1.0";
import { appleRootsBase64 } from "../_shared/apple-roots.ts";
import { appleVerifier } from "../_shared/apple-verifier.ts";
Deno.test("bundled Apple roots parse and verify their self-signatures in Deno", () => {
  assert.equal(appleRootsBase64.length, 3);
  for (const encoded of appleRootsBase64) {
    const cert = new X509Certificate(Buffer.from(encoded, "base64"));
    assert.match(cert.subject, /Apple/);
    assert.equal(cert.ca, true);
    assert.equal(cert.verify(cert.publicKey), true);
  }
});
Deno.test("official verifier rejects attacker-signed JWS and forged Apple certificate chains", async () => {
  const { privateKey } = await generateKeyPair("ES256");
  const verifier = appleVerifier(true);
  for (
    const certs of [undefined, [
      appleRootsBase64[2],
      appleRootsBase64[2],
      appleRootsBase64[2],
    ]]
  ) {
    const signed = await new SignJWT({
      notificationType: "TEST",
      notificationUUID: "00000000-0000-4000-8000-000000000001",
      signedDate: Date.now(),
      version: "2.0",
      data: { bundleId: "com.statusxp.statusxp", environment: "Sandbox" },
    })
      .setProtectedHeader({ alg: "ES256", ...(certs ? { x5c: certs } : {}) })
      .sign(privateKey);
    await assert.rejects(() => verifier.verifyAndDecodeNotification(signed));
  }
});
