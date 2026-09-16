import { Environment, SignedDataVerifier } from '@apple/app-store-server-library';
import { appleRootsBase64 } from './apple-roots.js';

const verifiers = new Map();
const methods = {
  notification: 'verifyAndDecodeNotification',
  transaction: 'verifyAndDecodeTransaction',
  renewal: 'verifyAndDecodeRenewalInfo',
};

export async function verifyApplePayload({ kind, sandbox, signedPayload }) {
  // These identifiers and roots are server controlled, never supplied by a caller.
  if (!verifiers.has(sandbox)) {
    verifiers.set(sandbox, new SignedDataVerifier(
      appleRootsBase64.map((root) => Buffer.from(root, 'base64')),
      true,
      sandbox ? Environment.SANDBOX : Environment.PRODUCTION,
      'com.statusxp.statusxp',
      sandbox ? undefined : 6757080961,
    ));
  }
  return verifiers.get(sandbox)[methods[kind]](signedPayload);
}

export function isVerificationRequest(body) {
  return body !== null && typeof body === 'object' &&
    Object.hasOwn(methods, body.kind) && typeof body.sandbox === 'boolean' &&
    typeof body.signedPayload === 'string' && body.signedPayload.length > 0 &&
    body.signedPayload.length <= 128000;
}
