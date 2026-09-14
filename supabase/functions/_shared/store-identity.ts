// Inputs must come from the store API response, never from the request body.
export function matchesStoreAccount(value: unknown, expected: string, apple = false): boolean {
  if (value == null) return false; // Existing ownership must be checked in SQL.
  if (typeof value !== "string" || !value ||
      (apple ? value.toLowerCase() !== expected.toLowerCase() : value !== expected)) {
    throw new Error("Store purchase belongs to another account");
  }
  return true;
}

export function appleSubscriptionKey(originalId: unknown, sandbox: boolean): string {
  if (typeof originalId !== "string" || !/^[0-9]+$/.test(originalId)) {
    throw new Error("Missing App Store subscription identity");
  }
  return `${sandbox ? "sandbox" : "production"}:${originalId}`;
}

export async function googleSubscriptionKey(token: string, sandbox: boolean): Promise<string> {
  if (!token) throw new Error("Missing Google subscription identity");
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(token));
  const hash = Array.from(new Uint8Array(digest), b => b.toString(16).padStart(2, "0")).join("");
  return `${sandbox ? "sandbox" : "production"}:${hash}`;
}
