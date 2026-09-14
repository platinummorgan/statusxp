type Input = {
  requestId: string;
  gameTitle: string;
  achievementName: string;
  achievementDescription: string;
  platform: string;
};
type Result = { state: string; guide?: string };
export type Dependencies = {
  admit?: (user: string) => Promise<Response | null>;
  getUser: (token: string) => Promise<string | null>;
  reserve: (user: string, request: string, hash: string) => Promise<Result>;
  finish: (
    user: string,
    request: string,
    guide: string | null,
  ) => Promise<Result>;
  generate: (input: Input) => Promise<string>;
};
const headers = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
};
function reply(status: number, body: unknown) {
  return new Response(JSON.stringify(body), { status, headers });
}
async function readInput(req: Request): Promise<Input> {
  const reader = req.body?.getReader();
  if (!reader) throw new Error("body");
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 16000) {
        await reader.cancel();
        throw new Error("size");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.length;
  }
  const raw = JSON.parse(new TextDecoder().decode(bytes));
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    throw new Error("input");
  }
  const field = (key: string, max: number, required = false): string => {
    const value = raw[key] ?? "";
    if (
      typeof value !== "string" || value.length > max ||
      (required && !value.trim())
    ) throw new Error("field");
    return value.trim();
  };
  const requestId = field("requestId", 36, true).toLowerCase();
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
      .test(requestId)
  ) throw new Error("id");
  return {
    requestId,
    gameTitle: field("gameTitle", 300, true),
    achievementName: field("achievementName", 300, true),
    achievementDescription: field("achievementDescription", 4000),
    platform: field("platform", 80),
  };
}
export function createGuideHandler(deps: Dependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method === "OPTIONS") return new Response("ok", { headers });
    if (req.method !== "POST") return reply(405, { error: "Use POST." });
    const token = /^Bearer ([^\s]+)$/i.exec(
      req.headers.get("Authorization") ?? "",
    )?.[1];
    if (!token) return reply(401, { error: "Sign in to generate a guide." });
    try {
      const user = await deps.getUser(token);
      if (!user) return reply(401, { error: "Sign in to generate a guide." });
      let input: Input;
      try {
        input = await readInput(req);
      } catch {
        return reply(400, {
          error: "Invalid guide request. Update the app if needed.",
        });
      }
      const { requestId, ...content } = input;
      const digest = await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(JSON.stringify(content)),
      );
      const hash = Array.from(
        new Uint8Array(digest),
        (b) => b.toString(16).padStart(2, "0"),
      ).join("");
      const reservation = await deps.reserve(user, requestId, hash);
      if (reservation.state === "succeeded") {
        return reply(200, { guide: reservation.guide });
      }
      if (reservation.state === "failed") {
        return reply(422, {
          error: "Generation failed. Your credit was released.",
          code: "released",
        });
      }
      if (reservation.state === "no_credits") {
        return reply(402, { error: "No AI credits available." });
      }
      if (["pending", "busy", "conflict"].includes(reservation.state)) {
        return reply(409, {
          error:
            "A guide request is pending or this request ID was already used. Try again shortly.",
        });
      }
      if (reservation.state !== "reserved") throw new Error("reservation");
      if (deps.admit) {
        const denied = await deps.admit(user);
        if (denied) {
          const released = await deps.finish(user, requestId, null);
          if (released.state !== "failed") throw new Error("release");
          return new Response(
            JSON.stringify({ ...(await denied.json()), code: "released" }),
            { status: denied.status, headers: denied.headers },
          );
        }
      }
      let guide: string;
      try {
        guide = await deps.generate(input);
        if (
          typeof guide !== "string" || !guide.trim() || guide.length > 12000
        ) throw new Error("output");
      } catch {
        // Only refund known generation failure. Never refund an ambiguous commit.
        const released = await deps.finish(user, requestId, null);
        if (released.state !== "failed") throw new Error("release");
        return reply(422, {
          error: "Generation failed. Your credit was released.",
          code: "released",
        });
      }
      const settled = await deps.finish(user, requestId, guide);
      if (settled.state === "failed") {
        return reply(422, {
          error: "Generation expired. Your credit was released.",
          code: "released",
        });
      }
      if (settled.state !== "succeeded") throw new Error("settlement");
      return reply(200, { guide: settled.guide });
    } catch {
      return reply(503, {
        error:
          "Guide service unavailable. Retry to check this request without charging again.",
      });
    }
  };
}
