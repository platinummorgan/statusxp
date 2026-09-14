import { sealGoogleToken } from "../_shared/google-token-vault.ts";
import { currentAppleSubscription } from "../_shared/apple-subscription.ts";
import { appleApiToken } from "../_shared/apple-api.ts";
import { base64Url } from "../_shared/store-jwt.ts";
import { googleGet } from "../_shared/google-play.ts";
import { matchesStoreAccount, appleSubscriptionKey, googleSubscriptionKey } from "../_shared/store-identity.ts";
import { requireFutureStoreExpiry } from '../_shared/store-expiry.ts';
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

function decodeBase64UrlJson(value: string): Record<string, unknown> {
  const normalized = value.replaceAll("-", "+").replaceAll("_", "/");
  const padded = normalized.padEnd(Math.ceil(normalized.length / 4) * 4, "=");
  const bytes = Uint8Array.from(atob(padded), (char) => char.charCodeAt(0));
  return JSON.parse(new TextDecoder().decode(bytes));
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
    const accountBound = matchesStoreAccount(accountId, expectedAccountId);
    const matchingLine = data.lineItems?.find((item: any) =>
      item.productId === productId
    );
    if (!matchingLine) {
      throw new Error(
        "Google Play product does not match the requested product",
      );
    }
    const expiresAt = requireFutureStoreExpiry(matchingLine.expiryTime);
    return {
      platform: "google_play",
      transactionId: matchingLine.latestSuccessfulOrderId ?? data.latestOrderId ??
        `token:${await sha256(purchaseToken)}`,
      productId,
      productType: "subscription",
      state: data.subscriptionState,
      purchasedAt: data.startTime ?? null,
      expiresAt,
      isTest: data.testPurchase != null,
      metadata: {
        regionCode: data.regionCode,
        acknowledgementState: data.acknowledgementState,
        accountBound,
        subscriptionKey: await googleSubscriptionKey(purchaseToken, data.testPurchase != null),
        linkedSubscriptionKey: data.linkedPurchaseToken
          ? await googleSubscriptionKey(data.linkedPurchaseToken, data.testPurchase != null)
          : null,
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
  expectedUserId: string,
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
  let accountBound = matchesStoreAccount(payload.appAccountToken, expectedUserId, true);
  const isSubscription = productId === subscriptionId;
  if (!isSubscription && !consumableIds.has(productId)) {
    throw new Error("Unknown App Store product");
  }
  const appleSandbox = sandbox || payload.environment === "Sandbox";
  if (isSubscription) appleSubscriptionKey(payload.originalTransactionId, appleSandbox);
  const current = isSubscription ? await currentAppleSubscription(payload.originalTransactionId, appleSandbox) : null;
  if (current) {
    const currentAccountBound = matchesStoreAccount(current.accountToken, expectedUserId, true);
    accountBound = accountBound || currentAccountBound;
    if (current.status !== 1 && current.status !== 4) throw new Error("App Store subscription is not currently entitled");
  }
  const expiresAt = current ? requireFutureStoreExpiry(current.expiresAt) : null;
  return {
    platform: "app_store",
    transactionId: current?.transactionId ?? String(payload.transactionId),
    productId,
    productType: isSubscription ? "subscription" : "consumable",
    state: isSubscription ? "ACTIVE" : "PURCHASED",
    purchasedAt: current?.purchasedAt ?? (payload.purchaseDate
      ? new Date(Number(payload.purchaseDate)).toISOString()
      : null),
    expiresAt,
    isTest: sandbox || payload.environment === "Sandbox",
    metadata: {
      originalTransactionId: payload.originalTransactionId,
      environment: payload.environment,
      appleStatus: current?.status,
      accountBound,
      subscriptionKey: isSubscription
        ? appleSubscriptionKey(payload.originalTransactionId, sandbox || payload.environment === "Sandbox")
        : null,
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
    const verifiedAt = new Date().toISOString();
    let verified: VerifiedPurchase;
    if (platform === "google_play") {
      verified = await verifyGoogle(
        productId,
        String(body.verificationData ?? ""),
        await sha256Hex(user.id),
      );
    } else if (platform === "app_store") {
      verified = await verifyApple(productId, String(body.purchaseId ?? ""), user.id);
    } else {
      return json({ error: "Unsupported store platform" }, 400);
    }

    const admin = createClient(
      supabaseUrl,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
    );
    const encryptedToken = verified.platform === "google_play" && verified.productType === "subscription"
      ? await sealGoogleToken(String(body.verificationData ?? ""), String(verified.metadata.subscriptionKey)) : null;
    const { data, error } = await admin.rpc(encryptedToken ? "fulfill_google_purchase_with_token" : "fulfill_verified_store_purchase", {
      ...(encryptedToken ? { p_token_envelope: encryptedToken } : {}),
      p_user_id: user.id,
      p_platform: verified.platform,
      p_transaction_id: verified.transactionId,
      p_product_id: verified.productId,
      p_product_type: verified.productType,
      p_store_state: verified.state,
      p_purchased_at: verified.purchasedAt,
      p_expires_at: verified.expiresAt,
      p_is_test: verified.isTest,
      p_metadata: { ...verified.metadata, verifiedAt },
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
