/** A verified subscription must have a finite future expiry, never implicit infinity. */
export function requireFutureStoreExpiry(
  value: unknown,
  now = Date.now(),
): string {
  const millis = typeof value === "number"
    ? value
    : typeof value === "string"
    ? Date.parse(value)
    : NaN;
  if (
    !Number.isFinite(millis) || millis <= now ||
    !Number.isFinite(new Date(millis).getTime())
  ) {
    throw new Error("Subscription expiry is missing, invalid, or expired");
  }
  return new Date(millis).toISOString();
}
