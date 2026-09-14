import { appleSubscriptionKey } from "../_shared/store-identity.ts";
export type AppleSnapshot = {
  subscriptionKey: string;
  status: number;
  expiresAt: string | null;
  accountToken: string | null;
  transactionId: string;
  purchasedAt: string | null;
};
function date(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new Error("Invalid Apple date");
  }
  return new Date(value).toISOString();
}
// Both transaction and renewal must have been verified against Apple roots.
export function appleSnapshot(
  status: unknown,
  transaction: Record<string, any>,
  renewal: Record<string, any>,
  originalId: string,
  sandbox: boolean,
): AppleSnapshot {
  if (
    ![1, 2, 3, 4, 5].includes(status as number) ||
    transaction.originalTransactionId !== originalId ||
    renewal.originalTransactionId !== originalId ||
    transaction.productId !== "statusxp_premium_monthly" ||
    transaction.bundleId !== "com.statusxp.statusxp" ||
    transaction.environment !== (sandbox ? "Sandbox" : "Production") ||
    renewal.environment !== transaction.environment ||
    typeof transaction.transactionId !== "string"
  ) throw new Error("Unexpected Apple subscription");
  const effectiveStatus = transaction.revocationDate != null
    ? 5
    : status as number;
  const expiry = date(
    effectiveStatus === 4
      ? renewal.gracePeriodExpiresDate
      : transaction.expiresDate,
  );
  if ((effectiveStatus === 1 || effectiveStatus === 4) && expiry === null) {
    throw new Error("Missing Apple expiry");
  }
  if (
    transaction.appAccountToken != null &&
    typeof transaction.appAccountToken !== "string"
  ) throw new Error("Invalid Apple account");
  return {
    subscriptionKey: appleSubscriptionKey(originalId, sandbox),
    status: effectiveStatus,
    expiresAt: expiry,
    accountToken: transaction.appAccountToken ?? null,
    transactionId: transaction.transactionId,
    purchasedAt: date(transaction.purchaseDate),
  };
}
