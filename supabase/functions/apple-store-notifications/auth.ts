import { Buffer } from "node:buffer";
import { appleVerifier } from "../_shared/apple-verifier.ts";
import type { AppleNotice } from "./handler.ts";
const types = new Set([
  "SUBSCRIBED",
  "DID_RENEW",
  "DID_FAIL_TO_RENEW",
  "DID_CHANGE_RENEWAL_STATUS",
  "DID_CHANGE_RENEWAL_PREF",
  "EXPIRED",
  "GRACE_PERIOD_EXPIRED",
  "REFUND",
  "REFUND_REVERSED",
  "REFUND_DECLINED",
  "REVOKE",
  "RENEWAL_EXTENDED",
  "OFFER_REDEEMED",
  "PRICE_INCREASE",
]);
export async function verifyAppleNotice(signed: string): Promise<AppleNotice> {
  // Untrusted decoding selects a verifier only; authorization requires its full
  // certificate-chain, signature, environment, bundle and app-ID verification.
  const parts = signed.split(".");
  if (parts.length !== 3) throw new Error("Invalid Apple JWS");
  const hint = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
  const environment = hint.data?.environment;
  if (environment !== "Production" && environment !== "Sandbox") {
    throw new Error("Unsupported Apple envelope");
  }
  const sandbox = environment === "Sandbox";
  if (sandbox && Deno.env.get("APPLE_ALLOW_SANDBOX_NOTIFICATIONS") !== "true") {
    throw new Error("Sandbox notifications disabled");
  }
  const verifier = appleVerifier(sandbox);
  const verified = await verifier.verifyAndDecodeNotification(signed);
  if (
    typeof verified.notificationUUID !== "string" ||
    !/^[0-9a-f-]{36}$/i.test(verified.notificationUUID)
  ) throw new Error("Missing Apple notification ID");
  if (verified.notificationType === "TEST") {
    return {
      id: verified.notificationUUID,
      originalId: null,
      sandbox,
      accountToken: null,
    };
  }
  if (
    !types.has(verified.notificationType ?? "") ||
    !verified.data?.signedTransactionInfo
  ) throw new Error("Unsupported Apple notification");
  const transaction = await verifier.verifyAndDecodeTransaction(
    verified.data.signedTransactionInfo,
  );
  if (
    transaction.productId !== "statusxp_premium_monthly" ||
    typeof transaction.originalTransactionId !== "string" ||
    !/^[0-9]+$/.test(transaction.originalTransactionId)
  ) throw new Error("Unexpected Apple product");
  return {
    id: verified.notificationUUID,
    originalId: transaction.originalTransactionId,
    sandbox,
    accountToken: transaction.appAccountToken ?? null,
  };
}
