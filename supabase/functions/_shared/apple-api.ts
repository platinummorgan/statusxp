import { signJwt } from "./store-jwt.ts";
const packageId = "com.statusxp.statusxp";
export async function appleApiToken(): Promise<string> {
  const issuerId = Deno.env.get("APPLE_APP_STORE_ISSUER_ID");
  const keyId = Deno.env.get("APPLE_APP_STORE_KEY_ID");
  const privateKey = Deno.env.get("APPLE_APP_STORE_PRIVATE_KEY");
  if (!issuerId || !keyId || !privateKey) {
    throw new Error("App Store verification is not configured");
  }
  const now = Math.floor(Date.now() / 1000);
  return signJwt(
    { alg: "ES256", kid: keyId, typ: "JWT" },
    {
      iss: issuerId,
      iat: now,
      exp: now + 300,
      aud: "appstoreconnect-v1",
      bid: packageId,
    },
    privateKey,
    "ES256",
  );
}
