import { Buffer } from "node:buffer";
import {
  Environment,
  SignedDataVerifier,
} from "npm:@apple/app-store-server-library@3.1.0";
import { appleRootsBase64 } from "./apple-roots.ts";
export const appleBundleId = "com.statusxp.statusxp";
const verifiers = new Map<string, SignedDataVerifier>();
export function appleVerifier(sandbox: boolean) {
  const id = Number(Deno.env.get("APPLE_APP_STORE_APP_ID"));
  if (!sandbox && (!Number.isSafeInteger(id) || id <= 0)) {
    throw new Error("Apple app ID is not configured");
  }
  const key = `${sandbox}:${id}`;
  if (verifiers.has(key)) return verifiers.get(key)!;
  const verifier = new SignedDataVerifier(
    appleRootsBase64.map((c) => Buffer.from(c, "base64")),
    true,
    sandbox ? Environment.SANDBOX : Environment.PRODUCTION,
    appleBundleId,
    sandbox ? undefined : id,
  );
  verifiers.set(key, verifier);
  return verifier;
}
