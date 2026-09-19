import { googleSubscriptionKey } from "../_shared/store-identity.ts";
export const packageId = "com.statusxp.statusxp";
export const activeStates = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED",
]);
const states = new Set([
  ...activeStates,
  "SUBSCRIPTION_STATE_PENDING",
  "SUBSCRIPTION_STATE_PAUSED",
  "SUBSCRIPTION_STATE_ON_HOLD",
  "SUBSCRIPTION_STATE_EXPIRED",
  "SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED",
]);
export type GoogleSnapshot = {
  subscriptionKey: string;
  linkedSubscriptionKey: string | null;
  state: string;
  expiresAt: string | null;
  accountId: string | null;
};
export async function parseGoogleSnapshot(
  data: Record<string, any>,
  token: string,
): Promise<GoogleSnapshot> {
  if (!states.has(data.subscriptionState) || !Array.isArray(data.lineItems)) {
    throw new Error("Invalid Play state");
  }
  const lines = data.lineItems.filter((line: any) =>
    line.productId === "statusxp_premium_monthly"
  );
  if (!lines.length) throw new Error("Unexpected Play product");
  const expiries: number[] = [];
  for (const line of lines) {
    if (line.expiryTime == null && !activeStates.has(data.subscriptionState)) {
      continue;
    }
    if (
      typeof line.expiryTime !== "string" ||
      !Number.isFinite(Date.parse(line.expiryTime))
    ) throw new Error("Invalid Play expiry");
    expiries.push(Date.parse(line.expiryTime));
  }
  const accountId =
    data.externalAccountIdentifiers?.obfuscatedExternalAccountId ?? null;
  if (accountId !== null && typeof accountId !== "string") {
    throw new Error("Invalid Play account");
  }
  if (
    data.linkedPurchaseToken != null &&
    typeof data.linkedPurchaseToken !== "string"
  ) throw new Error("Invalid linked token");
  return {
    subscriptionKey: await googleSubscriptionKey(
      token,
      data.testPurchase != null,
    ),
    linkedSubscriptionKey: data.linkedPurchaseToken
      ? await googleSubscriptionKey(
        data.linkedPurchaseToken,
        data.testPurchase != null,
      )
      : null,
    state: data.subscriptionState,
    expiresAt: expiries.length
      ? new Date(Math.max(...expiries)).toISOString()
      : null,
    accountId,
  };
}
