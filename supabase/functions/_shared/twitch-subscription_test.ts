import assert from "node:assert/strict";
import { currentTwitchSubscription } from "./twitch-subscription.ts";
function settings(body: unknown, status = 200) {
  return {
    broadcaster: "10",
    token: "fixture",
    client: "client",
    request: (async (input: RequestInfo | URL) => {
      const url = new URL(String(input));
      assert.equal(url.pathname, "/helix/subscriptions");
      assert.equal(url.searchParams.get("user_id"), "20");
      return new Response(JSON.stringify(body), { status });
    }) as typeof fetch,
  };
}
Deno.test("subscription query requires exact broadcaster and user match", async () => {
  assert.equal(
    await currentTwitchSubscription(
      "20",
      settings({ data: [{ user_id: "20", broadcaster_id: "10" }] }),
    ),
    true,
  );
  assert.equal(
    await currentTwitchSubscription(
      "20",
      settings({ data: [{ user_id: "21", broadcaster_id: "10" }] }),
    ),
    false,
  );
  assert.equal(
    await currentTwitchSubscription("20", settings({ data: [] })),
    false,
  );
});
Deno.test("API errors and malformed responses never mean unsubscribed", async () => {
  for (const status of [401, 403, 429, 500]) {
    await assert.rejects(() =>
      currentTwitchSubscription("20", settings({}, status))
    );
  }
  await assert.rejects(() =>
    currentTwitchSubscription("20", settings({ error: "unexpected" }))
  );
});
