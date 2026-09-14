import { appleApiToken } from "./apple-api.ts";
import { appleBundleId, appleVerifier } from "./apple-verifier.ts";
import {
  type AppleSnapshot,
  appleSnapshot,
} from "../apple-store-notifications/snapshot.ts";
export async function currentAppleSubscription(
  originalId: string,
  sandbox: boolean,
): Promise<AppleSnapshot> {
  const host = sandbox
    ? "api.storekit-sandbox.apple.com"
    : "api.storekit.apple.com";
  const response = await fetch(
    `https://${host}/inApps/v1/subscriptions/${encodeURIComponent(originalId)}`,
    {
      headers: { Authorization: `Bearer ${await appleApiToken()}` },
      signal: AbortSignal.timeout(10000),
    },
  );
  if (!response.ok) throw new Error("Apple subscription lookup unavailable");
  const body = await response.json();
  return resolveAppleStatus(body, originalId, sandbox, appleVerifier(sandbox));
}
type StatusVerifier = {
  verifyAndDecodeTransaction: (signed: string) => Promise<Record<string, any>>;
  verifyAndDecodeRenewalInfo: (signed: string) => Promise<Record<string, any>>;
};
export async function resolveAppleStatus(
  body: any,
  originalId: string,
  sandbox: boolean,
  verifier: StatusVerifier,
): Promise<AppleSnapshot> {
  if (
    body.bundleId !== appleBundleId ||
    body.environment !== (sandbox ? "Sandbox" : "Production") ||
    !Array.isArray(body.data)
  ) throw new Error("Unexpected Apple response");
  const matches = body.data.flatMap((group: any) =>
    Array.isArray(group.lastTransactions) ? group.lastTransactions : []
  )
    .filter((row: any) => row.originalTransactionId === originalId);
  if (matches.length !== 1) throw new Error("Ambiguous Apple subscription");
  const row = matches[0];
  if (
    typeof row.signedTransactionInfo !== "string" ||
    typeof row.signedRenewalInfo !== "string"
  ) throw new Error("Missing signed Apple state");
  const [transaction, renewal] = await Promise.all([
    verifier.verifyAndDecodeTransaction(row.signedTransactionInfo),
    verifier.verifyAndDecodeRenewalInfo(row.signedRenewalInfo),
  ]);
  return appleSnapshot(row.status, transaction, renewal, originalId, sandbox);
}
