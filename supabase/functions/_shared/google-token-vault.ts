import { googleSubscriptionKey } from "./store-identity.ts";

export type TokenEnvelope = {
  version: 1;
  keyId: string;
  iv: string;
  ciphertext: string;
};
export type TokenKeys = { active: string; keys: Record<string, string> };
const encode = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes));
const decode = (value: string) =>
  Uint8Array.from(atob(value), (c) => c.charCodeAt(0));

export function googleTokenKeys(): TokenKeys {
  try {
    const keys = JSON.parse(Deno.env.get("GOOGLE_PLAY_TOKEN_KEYS") ?? "");
    const active = Deno.env.get("GOOGLE_PLAY_TOKEN_ACTIVE_KEY") ?? "";
    if (
      !/^[a-zA-Z0-9_-]{1,64}$/.test(active) || !keys ||
      typeof keys !== "object" || Array.isArray(keys)
    ) throw new Error();
    if (
      typeof keys[active] !== "string" || decode(keys[active]).length !== 32
    ) throw new Error();
    return { active, keys };
  } catch {
    throw new Error("Google token encryption is not configured");
  }
}
async function key(config: TokenKeys, id: string) {
  const value = config.keys[id];
  if (typeof value !== "string" || decode(value).length !== 32) {
    throw new Error("Unavailable token key");
  }
  return await crypto.subtle.importKey("raw", decode(value), "AES-GCM", false, [
    "encrypt",
    "decrypt",
  ]);
}
function aad(subject: string) {
  if (!/^(production|sandbox):[0-9a-f]{64}$/.test(subject)) {
    throw new Error("Invalid token identity");
  }
  return new TextEncoder().encode(`statusxp:google-play:v1:${subject}`);
}
async function checkToken(token: string, subject: string) {
  if (
    typeof token !== "string" || !token || token.length > 16000 ||
    await googleSubscriptionKey(token, subject.startsWith("sandbox:")) !==
      subject
  ) throw new Error("Invalid token identity");
}
export async function sealGoogleToken(
  token: string,
  subject: string,
  config = googleTokenKeys(),
): Promise<TokenEnvelope> {
  try {
    await checkToken(token, subject);
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const ciphertext = await crypto.subtle.encrypt(
      { name: "AES-GCM", iv, additionalData: aad(subject) },
      await key(config, config.active),
      new TextEncoder().encode(token),
    );
    return {
      version: 1,
      keyId: config.active,
      iv: encode(iv),
      ciphertext: encode(new Uint8Array(ciphertext)),
    };
  } catch {
    throw new Error("Unable to protect Google purchase token");
  }
}
export async function openGoogleToken(
  envelope: TokenEnvelope,
  subject: string,
  config = googleTokenKeys(),
): Promise<string> {
  try {
    if (
      envelope.version !== 1 || decode(envelope.iv).length !== 12 ||
      envelope.ciphertext.length > 86000
    ) throw new Error();
    const bytes = await crypto.subtle.decrypt(
      {
        name: "AES-GCM",
        iv: decode(envelope.iv),
        additionalData: aad(subject),
      },
      await key(config, envelope.keyId),
      decode(envelope.ciphertext),
    );
    const token = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
    await checkToken(token, subject);
    return token;
  } catch {
    throw new Error("Unable to open Google purchase token");
  }
}
