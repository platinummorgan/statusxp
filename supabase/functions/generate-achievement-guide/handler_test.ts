import assert from "node:assert/strict";
import { createGuideHandler, type Dependencies } from "./handler.ts";
const input = {
  requestId: "11111111-1111-4111-8111-111111111111",
  gameTitle: "Game",
  achievementName: "Win",
  achievementDescription: "Win once",
};
Deno.test('AI quota denial refunds before returning 429 and never calls provider', async () => {
  const f = fixture({admit: async () => new Response(JSON.stringify({error:'Limit reached'}), {status:429,headers:{'Retry-After':'5'}})});
  const response = await f.request();
  assert.equal(response.status,429);
  assert.equal(response.headers.get('Retry-After'),'5');
  assert.equal((await response.json()).code,'released');
  assert.deepEqual(f.calls,['reserve','refund']);
});
Deno.test('replaying a completed guide does not spend provider quota', async () => {
  const f = fixture({reserve: async () => ({state:'succeeded',guide:'Saved'}), admit:async()=>{throw new Error('Must not admit replay');}});
  assert.equal((await f.request()).status,200);
});
function fixture(overrides: Partial<Dependencies> = {}) {
  const calls: string[] = [];
  const handler = createGuideHandler({
    getUser: async (token) => token === "valid" ? "verified-user" : null,
    reserve: async (user, id, hash) => {
      calls.push("reserve");
      assert.equal(user, "verified-user");
      assert.equal(id, input.requestId);
      assert.match(hash, /^[a-f0-9]{64}$/);
      return { state: "reserved" };
    },
    generate: async () => {
      calls.push("generate");
      return "Guide";
    },
    finish: async (_user, _id, guide) => {
      calls.push(guide === null ? "refund" : "settle");
      return {
        state: guide === null ? "failed" : "succeeded",
        guide: guide ?? undefined,
      };
    },
    ...overrides,
  });
  const request = (body: unknown = input, token = "valid", method = "POST") =>
    handler(
      new Request("https://local/guide", {
        method,
        headers: { Authorization: `Bearer ${token}` },
        ...(method === "POST" ? { body: JSON.stringify(body) } : {}),
      }),
    );
  return { calls, request, handler };
}
Deno.test("rejects invalid identity before reservation", async () => {
  const f = fixture();
  assert.equal((await f.request(input, "fake")).status, 401);
  assert.deepEqual(f.calls, []);
});
Deno.test("method, required request ID, types and byte limits fail before spending", async () => {
  const f = fixture();
  assert.equal((await f.request(input, "valid", "GET")).status, 405);
  for (
    const body of [{ ...input, requestId: null }, { ...input, gameTitle: 3 }, {
      ...input,
      achievementDescription: "a".repeat(4001),
    }, { ...input, extra: "a".repeat(16001) }]
  ) assert.equal((await f.request(body)).status, 400);
  assert.deepEqual(f.calls, []);
});
Deno.test("reserves before generation and settles before delivery", async () => {
  const f = fixture();
  const response = await f.request({ ...input, userId: "attacker-selected" });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { guide: "Guide" });
  assert.deepEqual(f.calls, ["reserve", "generate", "settle"]);
});
for (
  const [state, status] of [
    ["no_credits", 402],
    ["pending", 409],
    ["busy", 409],
    ["conflict", 409],
    ["failed", 422],
    ["succeeded", 200],
  ] as const
) {
  Deno.test(`${state} does not call provider or charge again`, async () => {
    const f = fixture({
      reserve: async () => ({ state, guide: "Saved guide" }),
    });
    const response = await f.request();
    assert.equal(response.status, status);
    assert.deepEqual(f.calls, []);
    if (status === 200) {
      assert.deepEqual(await response.json(), { guide: "Saved guide" });
    }
  });
}
Deno.test("provider exceptions and empty outputs release credit", async () => {
  for (
    const generate of [async () => {
      throw new Error("secret");
    }, async () => ""]
  ) {
    const f = fixture({ generate });
    const response = await f.request();
    assert.equal(response.status, 422);
    assert.deepEqual(f.calls, ["reserve", "refund"]);
    assert.ok(!(await response.text()).includes("secret"));
  }
});
Deno.test("ambiguous settlement never refunds or exposes result", async () => {
  const f = fixture({
    finish: async () => {
      throw new Error("db secret");
    },
  });
  const response = await f.request();
  assert.equal(response.status, 503);
  assert.deepEqual(f.calls, ["reserve", "generate"]);
  assert.ok(!(await response.text()).includes("secret"));
});
Deno.test("failed refund stays retryable rather than promising release", async () => {
  const f = fixture({
    generate: async () => {
      throw new Error("provider");
    },
    finish: async () => {
      throw new Error("db");
    },
  });
  assert.equal((await f.request()).status, 503);
});
