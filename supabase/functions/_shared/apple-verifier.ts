export const appleBundleId = "com.statusxp.statusxp";

type Payload = Record<string, any>;
type Kind = "notification" | "transaction" | "renewal";
type Options = {
  url: string;
  secret: string;
  fetcher?: (url: string, init: RequestInit) => Promise<Response>;
};

// Apple performs certificate, signature, revocation, app and environment checks
// in the private Node service. No local fallback may skip those checks.
export function createAppleVerifierClient(sandbox: boolean, options: Options) {
  const url = new URL(options.url);
  if (url.protocol !== "https:" || url.username || url.password ||
    url.search || url.hash || (url.pathname !== "/" && url.pathname !== "")) {
    throw new Error("Invalid Apple verifier URL");
  }
  if (options.secret.length < 32 || /\s/.test(options.secret)) {
    throw new Error("Apple verifier authentication is not configured");
  }
  const fetcher = options.fetcher ?? fetch;
  async function verify(kind: Kind, signedPayload: string): Promise<Payload> {
    if (!signedPayload || signedPayload.length > 128000) throw new Error("Invalid signed Apple payload");
    const response = await fetcher(`${url.origin}/verify`, {
      method: "POST", redirect: "error", signal: AbortSignal.timeout(20000),
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${options.secret}` },
      body: JSON.stringify({ kind, sandbox, signedPayload }),
    });
    if (!response.ok) {
      await response.body?.cancel();
      throw new Error("Apple verification unavailable or rejected");
    }
    const body = await response.json();
    if (!body?.payload || typeof body.payload !== "object" || Array.isArray(body.payload)) {
      throw new Error("Invalid Apple verifier response");
    }
    return body.payload;
  }
  return {
    verifyAndDecodeNotification: (signed: string) => verify("notification", signed),
    verifyAndDecodeTransaction: (signed: string) => verify("transaction", signed),
    verifyAndDecodeRenewalInfo: (signed: string) => verify("renewal", signed),
  };
}

export function appleVerifier(sandbox: boolean) {
  const url = Deno.env.get("APPLE_VERIFIER_URL");
  const secret = Deno.env.get("APPLE_VERIFIER_SECRET");
  if (!url || !secret) throw new Error("Apple verifier service is not configured");
  return createAppleVerifierClient(sandbox, { url, secret });
}
