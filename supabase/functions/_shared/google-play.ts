import { signJwt } from "./store-jwt.ts";
async function googleAccessToken(): Promise<string> {
  const rawCredentials = Deno.env.get("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");
  if (!rawCredentials) {
    throw new Error("Google Play verification is not configured");
  }
  const credentials = JSON.parse(rawCredentials);
  const now = Math.floor(Date.now() / 1000);
  const assertion = await signJwt(
    { alg: "RS256", typ: "JWT" },
    {
      iss: credentials.client_email,
      scope: "https://www.googleapis.com/auth/androidpublisher",
      aud: credentials.token_uri ?? "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    },
    credentials.private_key,
    "RS256",
  );
  const response = await fetch(
    credentials.token_uri ?? "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      signal: AbortSignal.timeout(10000),
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    },
  );
  const body = await response.json();
  if (!response.ok || !body.access_token) {
    throw new Error("Unable to authenticate with Google Play");
  }
  return body.access_token;
}

export async function googleGet(path: string): Promise<Record<string, any>> {
  const response = await fetch(
    `https://androidpublisher.googleapis.com${path}`,
    {
      headers: { Authorization: `Bearer ${await googleAccessToken()}` },
      signal: AbortSignal.timeout(10000),
    },
  );
  const body = await response.json();
  if (!response.ok) {
    console.error(
      "Google Play verification failed",
      response.status,
      body?.error?.status,
    );
    throw new Error("Google Play rejected the purchase token");
  }
  return body;
}
