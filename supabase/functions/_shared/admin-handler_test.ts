import assert from "node:assert/strict";
import { type AdminAuthOptions, createAdminHandler } from "./admin-handler.ts";

const serviceRoleKey = "test-service-role-key";

function fixture(
  overrides: Partial<AdminAuthOptions> = {},
  failOperation = false,
) {
  let calls = 0;
  let authCalls = 0;
  const handler = createAdminHandler({
    method: "POST",
    auth: {
      serviceRoleKey,
      adminUserIds: ["admin-id"],
      getUser: (token) => {
        authCalls++;
        return Promise.resolve(
          token === "valid-admin"
            ? { data: { user: { id: "admin-id" } }, error: null }
            : token === "valid-member"
            ? { data: { user: { id: "member-id" } }, error: null }
            : { data: { user: null }, error: new Error("invalid token") },
        );
      },
      ...overrides,
    },
    execute: () => {
      calls++;
      if (failOperation) throw new Error("private database details");
      return Promise.resolve({ success: true });
    },
  });
  return { handler, calls: () => calls, authCalls: () => authCalls };
}

function request(authorization?: string, method = "POST") {
  return new Request("https://example.test/admin", {
    method,
    headers: authorization ? { Authorization: authorization } : {},
  });
}

for (
  const [name, header, status] of [
    ["missing authorization", undefined, 401],
    ["wrong authentication scheme", "Basic test-service-role-key", 401],
    ["empty bearer", "Bearer", 401],
    ["invalid token", "Bearer invalid", 401],
    ["ordinary authenticated member", "Bearer valid-member", 403],
    ["service key with suffix", "Bearer test-service-role-key-extra", 401],
  ] as const
) {
  Deno.test(`admin gate rejects ${name} before executing`, async () => {
    const f = fixture();
    const response = await f.handler(request(header));
    assert.equal(response.status, status);
    assert.equal(f.calls(), 0);
    assert.equal(response.headers.get("Cache-Control"), "no-store");
    assert.doesNotMatch(await response.text(), /test-service-role-key/);
  });
}

Deno.test("service automation is allowed without an admin user allowlist", async () => {
  const f = fixture({ adminUserIds: [] });
  const response = await f.handler(request(`Bearer ${serviceRoleKey}`));
  assert.equal(response.status, 200);
  assert.equal(f.calls(), 1);
  assert.equal(f.authCalls(), 0);
});

Deno.test("only verified allowlisted identities may administer", async () => {
  const f = fixture();
  assert.equal((await f.handler(request("bearer valid-admin"))).status, 200);
  assert.equal(f.calls(), 1);
  assert.equal(f.authCalls(), 1);
});

Deno.test("an empty allowlist never grants user access", async () => {
  const f = fixture({ adminUserIds: [] });
  assert.equal((await f.handler(request("Bearer valid-admin"))).status, 403);
  assert.equal(f.calls(), 0);
});

Deno.test("auth errors deny even if a user ID is returned", async () => {
  const f = fixture({
    getUser: () =>
      Promise.resolve({
        data: { user: { id: "admin-id" } },
        error: new Error("expired"),
      }),
  });
  assert.equal((await f.handler(request("Bearer expired"))).status, 401);
  assert.equal(f.calls(), 0);
});

Deno.test("auth outage denies access without exposing internal errors", async () => {
  const f = fixture({
    getUser: () => Promise.reject(new Error("private auth details")),
  });
  const response = await f.handler(request("Bearer valid-admin"));
  assert.equal(response.status, 503);
  assert.equal(f.calls(), 0);
  assert.doesNotMatch(await response.text(), /private auth/);
});

Deno.test("missing server credentials cannot grant administrative access", async () => {
  const f = fixture({ serviceRoleKey: " " });
  assert.equal((await f.handler(request("Bearer valid-admin"))).status, 503);
  assert.equal(f.calls(), 0);
});

Deno.test("preflight is harmless and GET cannot invoke a POST operation", async () => {
  const f = fixture();
  assert.equal((await f.handler(request(undefined, "OPTIONS"))).status, 204);
  const response = await f.handler(request(`Bearer ${serviceRoleKey}`, "GET"));
  assert.equal(response.status, 405);
  assert.equal(response.headers.get("Allow"), "POST, OPTIONS");
  assert.equal(f.calls(), 0);
  assert.equal(f.authCalls(), 0);
});

Deno.test("database failure is not acknowledged as successful", async () => {
  const f = fixture({}, true);
  const response = await f.handler(request(`Bearer ${serviceRoleKey}`));
  assert.equal(response.status, 500);
  assert.equal(f.calls(), 1);
  assert.doesNotMatch(await response.text(), /private database/);
});

Deno.test("legacy handler responses retain status and gain no-store headers", async () => {
  const handler = createAdminHandler({
    method: "GET",
    auth: {
      serviceRoleKey,
      adminUserIds: [],
      getUser: () => Promise.reject("unused"),
    },
    execute: () => Promise.resolve(new Response("retired", { status: 410 })),
  });
  const response = await handler(request(`Bearer ${serviceRoleKey}`, "GET"));
  assert.equal(response.status, 410);
  assert.equal(await response.text(), "retired");
  assert.equal(response.headers.get("Cache-Control"), "no-store");
});
