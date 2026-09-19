import assert from "node:assert/strict";
import { createTwitchHandler, type TwitchDependencies } from "./handler.ts";
const now = Date.parse("2026-09-12T12:00:00Z");
const secret = "local_fixture_secret";
const payload = {
  subscription: {
    type: "channel.subscribe",
    condition: { broadcaster_user_id: "10" },
  },
  event: { user_id: "20", broadcaster_user_id: "10" },
};
async function request(
  body: unknown = payload,
  time = new Date(now).toISOString(),
  kind = "notification",
) {
  const text = JSON.stringify(body);
  const id = "message-1";
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const hash = await crypto.subtle.sign(
    "HMAC",
    key,
    encoder.encode(id + time + text),
  );
  const hex = Array.from(
    new Uint8Array(hash),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
  return new Request("https://local/twitch", {
    method: "POST",
    body: text,
    headers: {
      "twitch-eventsub-message-id": id,
      "twitch-eventsub-message-timestamp": time,
      "twitch-eventsub-message-type": kind,
      "twitch-eventsub-message-signature": `sha256=${hex}`,
    },
  });
}
function fixture(overrides: Partial<TwitchDependencies> = {}) {
  const calls: string[] = [];
  const handler = createTwitchHandler({
    secret,
    broadcasterId: "10",
    now: () => now,
    check: async (user) => {
      assert.equal(user, "20");
      calls.push("check");
      return true;
    },
    apply: async (o) => {
      calls.push(o.active === null ? "ignore" : "apply");
    },
    ...overrides,
  });
  return { handler, calls };
}
Deno.test("signed notification reconciles before committing", async () => {
  const f = fixture();
  assert.equal((await f.handler(await request())).status, 200);
  assert.deepEqual(f.calls, ["check", "apply"]);
});
Deno.test("old and future signed messages do not change entitlements", async () => {
  const f = fixture();
  for (const offset of [-600001, 60001]) {
    assert.equal(
      (await f.handler(
        await request(payload, new Date(now + offset).toISOString()),
      )).status,
      403,
    );
  }
  assert.deepEqual(f.calls, []);
});
Deno.test("tampered body fails real HMAC verification", async () => {
  const f = fixture();
  const valid = await request();
  const tampered = new Request(valid.url, {
    method: "POST",
    headers: valid.headers,
    body: "{}",
  });
  assert.equal((await f.handler(tampered)).status, 403);
  assert.deepEqual(f.calls, []);
});
Deno.test("gift donor event cannot grant donor premium", async () => {
  const f = fixture();
  assert.equal(
    (await f.handler(
      await request({
        ...payload,
        subscription: {
          ...payload.subscription,
          type: "channel.subscription.gift",
        },
      }),
    )).status,
    200,
  );
  assert.deepEqual(f.calls, ["ignore"]);
});
Deno.test("duplicate receipt skips API call and mutation", async () => {
  const f = fixture({ seen: async () => true });
  assert.equal((await f.handler(await request())).status, 200);
  assert.deepEqual(f.calls, []);
});
Deno.test("provider failure cannot be treated as non-subscriber", async () => {
  const f = fixture({
    check: async () => {
      throw new Error("private token");
    },
  });
  const result = await f.handler(await request());
  assert.equal(result.status, 503);
  assert.deepEqual(f.calls, []);
  assert.ok(!(await result.text()).includes("token"));
});
Deno.test("database failure is not acknowledged", async () => {
  const f = fixture({
    apply: async () => {
      throw new Error("db");
    },
  });
  assert.equal((await f.handler(await request())).status, 503);
});
Deno.test("challenge echoes only verified challenge with byte length", async () => {
  const f = fixture();
  const response = await f.handler(
    await request(
      { ...payload, challenge: "challenge-value" },
      undefined,
      "webhook_callback_verification",
    ),
  );
  assert.equal(response.status, 200);
  assert.equal(await response.text(), "challenge-value");
  assert.equal(response.headers.get("Content-Length"), "15");
  assert.deepEqual(f.calls, []);
});
Deno.test("another broadcaster is rejected", async () => {
  const f = fixture();
  assert.equal(
    (await f.handler(
      await request({
        ...payload,
        subscription: {
          ...payload.subscription,
          condition: { broadcaster_user_id: "99" },
        },
      }),
    )).status,
    403,
  );
  assert.deepEqual(f.calls, []);
});
