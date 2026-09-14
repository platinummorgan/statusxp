import assert from "node:assert/strict";
import { requireFutureStoreExpiry } from "./store-expiry.ts";
const now = Date.parse("2026-09-12T12:00:00Z");
Deno.test("store expiry rejects missing, invalid, expired and boundary values", () => {
  for (
    const expiry of [
      null,
      undefined,
      "",
      false,
      "invalid",
      NaN,
      Infinity,
      now,
      now - 1,
    ]
  ) {
    assert.throws(() => requireFutureStoreExpiry(expiry, now));
  }
});
Deno.test("Google ISO and Apple millisecond expiry normalize identically", () => {
  const iso = "2026-09-13T12:00:00.000Z";
  assert.equal(requireFutureStoreExpiry(iso, now), iso);
  assert.equal(requireFutureStoreExpiry(Date.parse(iso), now), iso);
});
