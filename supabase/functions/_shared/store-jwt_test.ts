import assert from "node:assert/strict";
import { exportPKCS8, generateKeyPair, jwtVerify } from "npm:jose@6.1.0";
import { signJwt } from "./store-jwt.ts";
Deno.test("shared store signer produces valid Google RSA and Apple EC JWTs", async () => {
  for (const alg of ["RS256", "ES256"] as const) {
    const { privateKey, publicKey } = await generateKeyPair(alg, {
      extractable: true,
    });
    const token = await signJwt(
      { alg, typ: "JWT" },
      { iss: "store-fixture" },
      await exportPKCS8(privateKey),
      alg,
    );
    const result = await jwtVerify(token, publicKey, {
      algorithms: [alg],
      issuer: "store-fixture",
    });
    assert.equal(result.payload.iss, "store-fixture");
  }
});
