import type { AppleSnapshot } from "./snapshot.ts";
export type AppleNotice = {
  id: string;
  originalId: string | null;
  sandbox: boolean;
  accountToken: string | null;
};
export type AppleDependencies = {
  verify: (signed: string) => Promise<AppleNotice>;
  seen: (id: string, hash: string) => Promise<boolean>;
  lookup: (id: string, sandbox: boolean) => Promise<AppleSnapshot>;
  apply: (
    id: string,
    hash: string,
    observedAt: string,
    snapshot: AppleSnapshot | null,
  ) => Promise<void>;
  now?: () => number;
};
export function createAppleHandler(deps: AppleDependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return new Response("Use POST", { status: 405 });
    let signed: string;
    try {
      const reader = req.body?.getReader();
      if (!reader) throw new Error("Missing body");
      let body = "", size = 0;
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
      signed = JSON.parse(body).signedPayload;
      if (typeof signed !== "string" || !signed) throw new Error("Missing JWS");
    } catch {
      return new Response("Invalid notification", { status: 400 });
    }
    try {
      const notice = await deps.verify(signed);
      const digest = await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(signed),
      );
      const hash = Array.from(
        new Uint8Array(digest),
        (b) => b.toString(16).padStart(2, "0"),
      ).join("");
      if (await deps.seen(notice.id, hash)) {
        return new Response(null, { status: 204 });
      }
      const observedAt = new Date((deps.now ?? Date.now)()).toISOString();
      const snapshot = notice.originalId
        ? await deps.lookup(notice.originalId, notice.sandbox)
        : null;
      if (
        snapshot && notice.accountToken && snapshot.accountToken &&
        notice.accountToken.toLowerCase() !==
          snapshot.accountToken.toLowerCase()
      ) throw new Error("Account changed");
      if (snapshot) snapshot.accountToken ??= notice.accountToken;
      await deps.apply(notice.id, hash, observedAt, snapshot);
      return new Response(null, { status: 204 });
    } catch {
      return new Response("Verification or reconciliation unavailable", {
        status: 503,
      });
    }
  };
}
