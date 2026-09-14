type Observation = {
  messageId: string;
  bodyHash: string;
  signedAt: string;
  twitchUserId: string | null;
  active: boolean | null;
};
export type TwitchDependencies = {
  secret: string;
  broadcasterId: string;
  now?: () => number;
  seen?: (messageId: string, bodyHash: string) => Promise<boolean>;
  check: (user: string) => Promise<boolean>;
  apply: (observation: Observation) => Promise<void>;
};
export function createTwitchHandler(deps: TwitchDependencies) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return new Response("Use POST", { status: 405 });
    if (!deps.secret || !deps.broadcasterId) {
      return new Response("Unavailable", { status: 503 });
    }
    const messageId = req.headers.get("twitch-eventsub-message-id");
    const signedAt = req.headers.get("twitch-eventsub-message-timestamp");
    const signature = req.headers.get("twitch-eventsub-message-signature");
    const kind = req.headers.get("twitch-eventsub-message-type");
    const now = (deps.now ?? Date.now)();
    const time = Date.parse(signedAt ?? "");
    if (
      !messageId || messageId.length > 200 || !signedAt ||
      !Number.isFinite(time) || time < now - 600000 || time > now + 60000 ||
      !/^sha256=[a-f0-9]{64}$/.test(signature ?? "")
    ) return new Response("Invalid message", { status: 403 });
    let body = "";
    try {
      const reader = req.body?.getReader();
      if (!reader) return new Response("Missing body", { status: 400 });
      let size = 0;
      const decoder = new TextDecoder();
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
      const encoder = new TextEncoder();
      const key = await crypto.subtle.importKey(
        "raw",
        encoder.encode(deps.secret),
        { name: "HMAC", hash: "SHA-256" },
        false,
        ["verify"],
      );
      const bytes = Uint8Array.from(
        signature!.slice(7).match(/../g)!,
        (b) => parseInt(b, 16),
      );
      if (
        !await crypto.subtle.verify(
          "HMAC",
          key,
          bytes,
          encoder.encode(messageId + signedAt + body),
        )
      ) return new Response("Invalid signature", { status: 403 });
      const payload = JSON.parse(body);
      if (
        payload.subscription?.condition?.broadcaster_user_id !==
          deps.broadcasterId
      ) return new Response("Wrong broadcaster", { status: 403 });
      if (kind === "webhook_callback_verification") {
        if (typeof payload.challenge !== "string") {
          return new Response("Invalid challenge", { status: 400 });
        }
        return new Response(payload.challenge, {
          headers: {
            "Content-Type": "text/plain",
            "Content-Length": String(encoder.encode(payload.challenge).length),
          },
        });
      }
      const hash = await crypto.subtle.digest("SHA-256", encoder.encode(body));
      const observation: Observation = {
        messageId,
        bodyHash: Array.from(
          new Uint8Array(hash),
          (b) => b.toString(16).padStart(2, "0"),
        ).join(""),
        signedAt,
        twitchUserId: null,
        active: null,
      };
      if (deps.seen && await deps.seen(messageId, observation.bodyHash)) {
        return new Response("ok");
      }
      if (kind === "notification") {
        const type = payload.subscription.type;
        // Gift events identify the donor. Recipient subscriptions arrive through channel.subscribe.
        if (
          [
            "channel.subscribe",
            "channel.subscription.message",
            "channel.subscription.end",
          ].includes(type)
        ) {
          const user = payload.event?.user_id;
          if (
            typeof user !== "string" || !/^\d+$/.test(user) ||
            payload.event?.broadcaster_user_id !== deps.broadcasterId
          ) return new Response("Invalid event", { status: 400 });
          observation.twitchUserId = user;
          observation.active = await deps.check(user);
        }
      } else if (kind !== "revocation") {
        return new Response("Invalid message type", { status: 400 });
      } else {
        console.warn(
          "Twitch EventSub subscription revoked; check delivery configuration.",
        );
      }
      await deps.apply(observation);
      return new Response("ok");
    } catch {
      return new Response("Processing unavailable", { status: 503 });
    }
  };
}
