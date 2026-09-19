import { type GoogleSnapshot, packageId } from "./snapshot.ts";
export type GoogleNotificationDependencies = {
  subscription: string;
  authenticate: (header: string | null) => Promise<void>;
  seen: (id: string, hash: string) => Promise<boolean>;
  lookup: (token: string) => Promise<GoogleSnapshot>;
  apply: (
    id: string,
    hash: string,
    observedAt: string,
    snapshot: GoogleSnapshot | null,
    token: string | null,
  ) => Promise<void>;
  now?: () => number;
};
export function createGoogleNotificationHandler(
  deps: GoogleNotificationDependencies,
) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return new Response("Use POST", { status: 405 });
    if (!deps.subscription) return new Response("Unavailable", { status: 503 });
    try {
      await deps.authenticate(req.headers.get("authorization"));
    } catch {
      return new Response("Unauthorized", { status: 401 });
    }
    let envelope: any;
    try {
      const reader = req.body?.getReader();
      if (!reader) return new Response("Missing body", { status: 400 });
      let size = 0, body = "";
      const decoder = new TextDecoder("utf-8", { fatal: true });
      try {
        while (true) {
          const { value, done } = await reader.read();
          if (done) break;
          size += value.length;
          if (size > 128000) {
            await reader.cancel();
            return new Response("Too large", { status: 413 });
          }
          body += decoder.decode(value, { stream: true });
        }
        body += decoder.decode();
      } finally {
        reader.releaseLock();
      }
      envelope = JSON.parse(body);
      if (envelope.subscription !== deps.subscription) {
        return new Response("Wrong subscription", { status: 403 });
      }
      if (
        typeof envelope.message?.messageId !== "string" ||
        !/^[0-9]{1,100}$/.test(envelope.message.messageId) ||
        typeof envelope.message.data !== "string"
      ) throw new Error("Invalid envelope");
    } catch {
      return new Response("Invalid message", { status: 400 });
    }
    let payload: any;
    let bytes: Uint8Array;
    try {
      bytes = Uint8Array.from(
        atob(envelope.message.data),
        (c) => c.charCodeAt(0),
      );
      payload = JSON.parse(
        new TextDecoder("utf-8", { fatal: true }).decode(bytes),
      );
      if (payload.packageName !== packageId) {
        return new Response("Wrong package", { status: 403 });
      }
      if (
        [
          "testNotification",
          "subscriptionNotification",
          "voidedPurchaseNotification",
          "oneTimeProductNotification",
          "pendingRefundReviewNotification",
        ]
          .filter((k) => payload[k] != null).length !== 1
      ) throw new Error("Ambiguous notification");
    } catch {
      return new Response("Invalid notification", { status: 400 });
    }
    const notification = payload.subscriptionNotification ??
      (payload.voidedPurchaseNotification?.productType === 1
        ? payload.voidedPurchaseNotification
        : null);
    if (!payload.testNotification && !notification) {
      return new Response("Unsupported notification", { status: 422 });
    }
    if (
      notification &&
      (typeof notification.purchaseToken !== "string" ||
        !notification.purchaseToken ||
        notification.purchaseToken.length > 16000)
    ) {
      return new Response("Invalid purchase token", { status: 400 });
    }
    try {
      const digest = await crypto.subtle.digest(
        "SHA-256",
        new Uint8Array(bytes),
      );
      const hash = Array.from(
        new Uint8Array(digest),
        (b) => b.toString(16).padStart(2, "0"),
      ).join("");
      const id = envelope.message.messageId;
      if (await deps.seen(id, hash)) return new Response(null, { status: 204 });
      // Event time is not authoritative: delayed deliveries query current state.
      const observedAt = new Date((deps.now ?? Date.now)()).toISOString();
      const snapshot = notification
        ? await deps.lookup(notification.purchaseToken)
        : null;
      await deps.apply(
        id,
        hash,
        observedAt,
        snapshot,
        notification?.purchaseToken ?? null,
      );
      return new Response(null, { status: 204 });
    } catch {
      return new Response("Reconciliation unavailable", { status: 503 });
    }
  };
}
