import assert from "node:assert/strict";
import { appleSubscriptionKey, googleSubscriptionKey, matchesStoreAccount } from "./store-identity.ts";
Deno.test("store account claims reject mismatch and malformed values", () => {
  assert.equal(matchesStoreAccount(undefined, "owner"), false);
  assert.equal(matchesStoreAccount("owner", "owner"), true);
  assert.equal(matchesStoreAccount("ABC", "abc", true), true);
  for (const value of ["", "other", true, 1, {}]) {
    assert.throws(() => matchesStoreAccount(value, "owner"));
  }
  assert.throws(() => matchesStoreAccount("ABC", "abc"));
});
Deno.test("Apple lineage requires a store ID and separates test environments", () => {
  assert.equal(appleSubscriptionKey("100000001", false), "production:100000001");
  assert.equal(appleSubscriptionKey("100000001", true), "sandbox:100000001");
  for (const value of [null, undefined, "", "undefined", 123]) {
    assert.throws(() => appleSubscriptionKey(value, false));
  }
});
Deno.test("Google lineage stores a deterministic digest instead of the purchase token", async () => {
  const first = await googleSubscriptionKey("private-purchase-token", false);
  assert.match(first, /^production:[a-f0-9]{64}$/);
  assert.equal(first, await googleSubscriptionKey("private-purchase-token", false));
  assert.notEqual(first, await googleSubscriptionKey("different-token", false));
  assert.notEqual(first, await googleSubscriptionKey("private-purchase-token", true));
  assert.ok(!first.includes("private-purchase-token"));
  await assert.rejects(() => googleSubscriptionKey("", false));
});
