export type ArtInput = {
  requestId: string;
  platformId: number;
  gameId: string;
  style: string;
};
export type ArtDependencies = {
  getUser: (token: string) => Promise<string | null>;
  available: () => boolean;
  reserve: (
    user: string,
    input: ArtInput,
    hash: string,
  ) => Promise<{ state: string; game_name?: string; object_path?: string }>;
  generate: (user: string, input: ArtInput, game: string) => Promise<string>;
  finish: (user: string, id: string, path: string | null) => Promise<boolean>;
  remove: (path: string) => Promise<void>;
};
const headers = {
  "Content-Type": "application/json",
  "Cache-Control": "no-store",
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const reply = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers });
async function input(req: Request): Promise<ArtInput> {
  const reader = req.body?.getReader();
  if (!reader) throw new Error("body");
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.length;
      if (size > 8192) {
        await reader.cancel();
        throw new Error("size");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let at = 0;
  for (const c of chunks) {
    bytes.set(c, at);
    at += c.length;
  }
  const raw = JSON.parse(new TextDecoder().decode(bytes));
  if (
    !raw || typeof raw !== "object" ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
      .test(raw.requestId ?? "") ||
    ![1, 2, 5, 9].includes(raw.platformId) || typeof raw.gameId !== "string" ||
    !raw.gameId.trim() || raw.gameId.length > 200 ||
    !["cinematic", "painted", "cosmic"].includes(raw.style)
  ) throw new Error("input");
  return {
    requestId: raw.requestId,
    platformId: raw.platformId,
    gameId: raw.gameId.trim(),
    style: raw.style,
  };
}
export function createPlatinumArtHandler(deps: ArtDependencies) {
  return async (req: Request) => {
    if (req.method === "OPTIONS") return new Response("ok", { headers });
    if (req.method !== "POST") return reply(405, { code: "method" });
    const token = /^Bearer (\S+)$/i.exec(req.headers.get("Authorization") ?? "")
      ?.[1];
    if (!token) return reply(401, { code: "sign_in" });
    let user: string | null;
    try {
      user = await deps.getUser(token);
    } catch {
      return reply(503, { code: "unavailable" });
    }
    if (!user) return reply(401, { code: "sign_in" });
    let value: ArtInput;
    try {
      value = await input(req);
    } catch {
      return reply(400, { code: "invalid_input" });
    }
    if (!deps.available()) return reply(503, { code: "unavailable" });
    try {
      const hash = Array.from(
        new Uint8Array(
          await crypto.subtle.digest(
            "SHA-256",
            new TextEncoder().encode(
              JSON.stringify([value.platformId, value.gameId, value.style]),
            ),
          ),
        ),
        (b) => b.toString(16).padStart(2, "0"),
      ).join("");
      const reservation = await deps.reserve(user, value, hash);
      if (reservation.state === "premium_required") {
        return reply(402, { code: "premium_required" });
      }
      if (reservation.state === "not_owned") {
        return reply(403, { code: "not_owned" });
      }
      if (reservation.state === "limit_reached") {
        return reply(429, { code: "limit_reached" });
      }
      if (reservation.state === "succeeded" && reservation.object_path) {
        return reply(200, { objectPath: reservation.object_path });
      }
      if (["failed", "abandoned"].includes(reservation.state)) {
        return reply(422, { code: reservation.state });
      }
      if (reservation.state !== "reserved") {
        return reply(409, { code: reservation.state });
      }
      let path: string;
      try {
        path = await deps.generate(user, value, reservation.game_name!);
      } catch {
        const released = await deps.finish(user, value.requestId, null);
        return reply(released ? 422 : 503, {
          code: released ? "failed" : "unavailable",
        });
      }
      if (!await deps.finish(user, value.requestId, path)) {
        await deps.remove(path);
        return reply(503, { code: "save_failed" });
      }
      return reply(200, { objectPath: path });
    } catch {
      return reply(503, { code: "unavailable" });
    }
  };
}
