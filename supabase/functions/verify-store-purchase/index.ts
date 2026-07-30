import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const packageId = "com.statusxp.statusxp";
const subscriptionId = "statusxp_premium_monthly";
const consumableIds = new Set([
  "statusxp_ai_pack_small",
  "statusxp_ai_pack_medium",
  "statusxp_ai_pack_large",
]);

type VerifiedPurchase = {
  platform: "google_play" | "app_store";
  transactionId: string;
  productId: string;
  productType: "subscription" | "consumable";
  state: string;
  purchasedAt: string | null;
  expiresAt: string | null;
  isTest: boolean;
  metadata: Record<string, unknown>;
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function base64Url(input: Uint8Array | string): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(
    /=+$/,
    "",
  );
}

function decodeBase64UrlJson(value: string): Record<string, unknown> {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const bytes = Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
  return JSON.parse(new TextDecoder().decode(bytes));
}

function pemToDer(pem: string): Uint8Array {
  const content = pem.replaceAll("\\n", "\n")
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s/g, "");
  return Uint8Array.from(atob(content), (char) => char.charCodeAt(0));
}

async function signJwt(
  header: Record<string, unknown>,
  payload: Record<string, unknown>,
  privateKeyPem: string,
  algorithm: "RS256" | "ES256",
): Promise<string> {
  const signingInput = `${base64Url(JSON.stringify(header))}.${
    base64Url(JSON.stringify(payload))
  }`;
  const keyAlgorithm = algorithm === "RS256"
    ? { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }
    : { name: "ECDSA", namedCurve: "P-256" };
  const der = pemToDer(privateKeyPem);
  const keyData = der.buffer.slice(
    der.byteOffset,
    der.byteOffset + der.byteLength,
  ) as ArrayBuffer;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    keyAlgorithm,
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    algorithm === "RS256"
      ? { name: "RSASSA-PKCS1-v1_5" }
      : { name: "ECDSA", hash: "SHA-256" },
    key,
    new TextEncoder().encode(signingInput),
  );
  return `${signingInput}.${base64Url(new Uint8Array(signature))}`;
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return base64Url(new Uint8Array(digest));
}

async function sha256Hex(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return [...new Uint8Array(digest)]
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

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

async function googleGet(path: string): Promise<Record<string, any>> {
  const response = await fetch(
    `https://androidpublisher.googleapis.com${path}`,
    {
      headers: { Authorization: `Bearer ${await googleAccessToken()}` },
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

async function verifyGoogle(
  productId: string,
  purchaseToken: string,
  expectedAccountId: string,
): Promise<VerifiedPurchase> {
  if (!purchaseToken) throw new Error("Missing Google Play purchase token");

  if (productId === subscriptionId) {
    const data = await googleGet(
      `/androidpublisher/v3/applications/${packageId}/purchases/subscriptionsv2/tokens/${
        encodeURIComponent(purchaseToken)
      }`,
    );
    const activeStates = new Set([
      "SUBSCRIPTION_STATE_ACTIVE",
      "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
      "SUBSCRIPTION_STATE_CANCELED",
    ]);
    if (!activeStates.has(data.subscriptionState)) {
      throw new Error("Subscription is not currently entitled");
    }
    const accountId = data.externalAccountIdentifiers
      ?.obfuscatedExternalAccountId;
    if (accountId && accountId !== expectedAccountId) {
      throw new Error("Google Play purchase belongs to another account");
    }
    const matchingLine = data.lineItems?.find((item: any) =>
      item.productId === productId
    );
    if (!matchingLine) {
      throw new Error(
        "Google Play product does not match the requested product",
      );
    }
    if (
      matchingLine.expiryTime &&
      Date.parse(matchingLine.expiryTime) <= Date.now()
    ) {
      throw new Error("Subscription has expired");
    }
    return {
      platform: "google_play",
      transactionId: data.latestOrderId ??
        `token:${await sha256(purchaseToken)}`,
      productId,
      productType: "subscription",
      state: data.subscriptionState,
      purchasedAt: data.startTime ?? null,
      expiresAt: matchingLine.expiryTime ?? null,
      isTest: data.testPurchase != null,
      metadata: {
        regionCode: data.regionCode,
        acknowledgementState: data.acknowledgementState,
      },
    };
  }

  if (!consumableIds.has(productId)) {
    throw new Error("Unknown Google Play product");
  }
  const data = await googleGet(
    `/androidpublisher/v3/applications/${packageId}/purchases/productsv2/tokens/${
      encodeURIComponent(purchaseToken)
    }`,
  );
  if (data.purchaseStateContext?.purchaseState !== "PURCHASED") {
    throw new Error("Google Play purchase is not complete");
  }
  if (
    data.obfuscatedExternalAccountId &&
    data.obfuscatedExternalAccountId !== expectedAccountId
  ) {
    throw new Error("Google Play purchase belongs to another account");
  }
  const matchingLine = data.productLineItem?.find((item: any) =>
    item.productId === productId
  );
  if (!matchingLine) {
    throw new Error("Google Play product does not match the requested product");
  }
  return {
    platform: "google_play",
    transactionId: data.orderId ?? `token:${await sha256(purchaseToken)}`,
    productId,
    productType: "consumable",
    state: "PURCHASED",
    purchasedAt: data.purchaseCompletionTime ?? null,
    expiresAt: null,
    isTest: data.testPurchaseContext != null,
    metadata: {
      regionCode: data.regionCode,
      acknowledgementState: data.acknowledgementState,
    },
  };
}

async function appleApiToken(): Promise<string> {
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

async function fetchAppleTransaction(
  transactionId: string,
): Promise<{ payload: Record<string, any>; sandbox: boolean }> {
  const token = await appleApiToken();
  for (const sandbox of [false, true]) {
    const host = sandbox
      ? "api.storekit-sandbox.apple.com"
      : "api.storekit.apple.com";
    const response = await fetch(
      `https://${host}/inApps/v1/transactions/${
        encodeURIComponent(transactionId)
      }`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    if (response.status === 404 && !sandbox) continue;
    const body = await response.json();
    if (!response.ok || typeof body.signedTransactionInfo !== "string") {
      console.error(
        "App Store verification failed",
        response.status,
        body?.errorCode,
      );
      throw new Error("App Store rejected the transaction");
    }
    const parts = body.signedTransactionInfo.split(".");
    if (parts.length !== 3) {
      throw new Error("Invalid App Store transaction response");
    }
    return { payload: decodeBase64UrlJson(parts[1]), sandbox };
  }
  throw new Error("App Store transaction was not found");
}

async function verifyApple(
  productId: string,
  transactionId: string,
): Promise<VerifiedPurchase> {
  if (!transactionId) throw new Error("Missing App Store transaction ID");
  const { payload, sandbox } = await fetchAppleTransaction(transactionId);
  if (payload.bundleId !== packageId || payload.productId !== productId) {
    throw new Error("App Store transaction does not belong to this product");
  }
  if (
    String(payload.transactionId) !== transactionId &&
    String(payload.originalTransactionId) !== transactionId
  ) {
    throw new Error("App Store transaction identity mismatch");
  }
  if (payload.revocationDate != null) {
    throw new Error("App Store transaction was revoked");
  }
  const isSubscription = productId === subscriptionId;
  if (!isSubscription && !consumableIds.has(productId)) {
    throw new Error("Unknown App Store product");
  }
  if (
    isSubscription &&
    (!payload.expiresDate || Number(payload.expiresDate) <= Date.now())
  ) {
    throw new Error("App Store subscription has expired");
  }
  return {
    platform: "app_store",
    transactionId: String(payload.transactionId),
    productId,
    productType: isSubscription ? "subscription" : "consumable",
    state: isSubscription ? "ACTIVE" : "PURCHASED",
    purchasedAt: payload.purchaseDate
      ? new Date(Number(payload.purchaseDate)).toISOString()
      : null,
    expiresAt: payload.expiresDate
      ? new Date(Number(payload.expiresDate)).toISOString()
      : null,
    isTest: sandbox || payload.environment === "Sandbox",
    metadata: {
      originalTransactionId: payload.originalTransactionId,
      environment: payload.environment,
    },
  };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return json({ error: "Unauthorized" }, 401);
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const userClient = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      {
        global: { headers: { Authorization: authHeader } },
      },
    );
    const { data: { user }, error: authError } = await userClient.auth
      .getUser();
    if (authError || !user) return json({ error: "Unauthorized" }, 401);

    const body = await req.json();
    const platform = body.platform;
    const productId = String(body.productId ?? "");
    let verified: VerifiedPurchase;
    if (platform === "google_play") {
      verified = await verifyGoogle(
        productId,
        String(body.verificationData ?? ""),
        await sha256Hex(user.id),
      );
    } else if (platform === "app_store") {
      verified = await verifyApple(productId, String(body.purchaseId ?? ""));
    } else {
      return json({ error: "Unsupported store platform" }, 400);
    }

    const admin = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );
    const { data, error } = await admin.rpc("fulfill_verified_store_purchase", {
      p_user_id: user.id,
      p_platform: verified.platform,
      p_transaction_id: verified.transactionId,
      p_product_id: verified.productId,
      p_product_type: verified.productType,
      p_store_state: verified.state,
      p_purchased_at: verified.purchasedAt,
      p_expires_at: verified.expiresAt,
      p_is_test: verified.isTest,
      p_metadata: verified.metadata,
    });
    if (error) throw new Error(`Entitlement delivery failed: ${error.message}`);
    return json({ ...data, productId: verified.productId });
  } catch (error) {
    console.error(
      "Store purchase verification error",
      error instanceof Error ? error.message : error,
    );
    return json({
      error: error instanceof Error
        ? error.message
        : "Purchase verification failed",
    }, 400);
  }
});
