export type ProviderDependencies = {
  getUser: (token: string) => Promise<string | null>;
  admit: (user: string) => Promise<Response | null>;
  execute: (body: Record<string, unknown>) => Promise<unknown>;
  validate: (body: Record<string, unknown>) => boolean;
};
export const providerHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};
export function limitedProviderHandler(deps: ProviderDependencies) {
  const reply = (status: number, error: string) =>
    new Response(JSON.stringify({ error }), {
      status,
      headers: providerHeaders,
    });
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: providerHeaders });
    }
    if (req.method !== "POST") return reply(405, "Use POST.");
    const token = /^Bearer ([^\s]+)$/i.exec(
      req.headers.get("Authorization") ?? "",
    )?.[1];
    if (!token) return reply(401, "Sign in to continue.");
    try {
      const user = await deps.getUser(token);
      if (!user) return reply(401, "Sign in to continue.");
      let body;
      try {
        const reader = req.body?.getReader();
        if (!reader) return reply(400, "Request body required.");
        let text = "";
        let size = 0;
        const decoder = new TextDecoder();
        try {
          while (true) {
            const { value, done } = await reader.read();
            if (done) break;
            size += value.length;
            if (size > 24000) {
              await reader.cancel();
              return reply(413, "Request too large.");
            }
            text += decoder.decode(value, { stream: true });
          }
          text += decoder.decode();
        } finally {
          reader.releaseLock();
        }
        body = JSON.parse(text);
        if (
          !body || typeof body !== "object" || Array.isArray(body) ||
          !deps.validate(body)
        ) return reply(400, "Invalid request.");
      } catch {
        return reply(400, "Invalid request.");
      }
      const denied = await deps.admit(user);
      if (denied) return denied;
      return new Response(JSON.stringify(await deps.execute(body)), {
        headers: providerHeaders,
      });
    } catch {
      return reply(503, "Service unavailable. Try again later.");
    }
  };
}
