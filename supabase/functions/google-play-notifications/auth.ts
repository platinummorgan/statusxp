import {
  createRemoteJWKSet,
  jwtVerify,
  type JWTVerifyGetKey,
} from "npm:jose@6.1.0";
const googleKeys = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs"),
  { timeoutDuration: 10000 },
);
export function googlePushAuth(
  email: string,
  audience: string,
  keys: JWTVerifyGetKey = googleKeys,
) {
  return async (header: string | null): Promise<void> => {
    if (!email || !audience) {
      throw new Error("Push authentication unconfigured");
    }
    const token = /^Bearer ([^\s]+)$/i.exec(header ?? "")?.[1];
    if (!token) throw new Error("Missing bearer token");
    const { payload } = await jwtVerify(token, keys, {
      algorithms: ["RS256"],
      issuer: ["https://accounts.google.com", "accounts.google.com"],
      audience,
      requiredClaims: ["exp", "iat", "sub", "email", "email_verified"],
      clockTolerance: 5,
    });
    if (payload.email !== email || payload.email_verified !== true) {
      throw new Error("Unexpected push identity");
    }
  };
}
