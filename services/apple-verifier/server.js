import { createServer } from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { isVerificationRequest, verifyApplePayload } from './verifier.js';

export function createVerificationServer({ secret, verify = verifyApplePayload }) {
  if (typeof secret !== 'string' || secret.length < 32 || /\s/.test(secret)) {
    throw new Error('APPLE_VERIFIER_SECRET must contain at least 32 non-whitespace characters');
  }
  const expected = Buffer.from(secret);
  return createServer({ requestTimeout: 20000, headersTimeout: 10000 }, async (req, res) => {
    const reply = (status, body) => {
      res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
      res.end(JSON.stringify(body));
    };
    if (req.method === 'GET' && req.url === '/health') return reply(200, { ok: true });
    if (req.method !== 'POST' || req.url !== '/verify') return reply(404, { error: 'Not found' });
    const header = req.headers.authorization;
    const received = Buffer.from(typeof header === 'string' ? /^Bearer ([^\s]+)$/i.exec(header)?.[1] ?? '' : '');
    if (received.length !== expected.length || !timingSafeEqual(received, expected)) {
      return reply(401, { error: 'Unauthorized' });
    }
    if (req.headers['content-type']?.split(';')[0].trim() !== 'application/json') {
      return reply(415, { error: 'JSON required' });
    }
    let body;
    try {
      const chunks = [];
      let bytes = 0;
      for await (const chunk of req) {
        bytes += chunk.length;
        if (bytes > 132000) return reply(413, { error: 'Too large' });
        chunks.push(chunk);
      }
      body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    } catch {
      return reply(400, { error: 'Invalid request' });
    }
    if (!isVerificationRequest(body)) return reply(400, { error: 'Invalid request' });
    try {
      const payload = await verify(body);
      return reply(200, { payload });
    } catch (error) {
      // No signed bodies, decoded transactions, credentials or raw errors in logs/responses.
      const status = Number.isInteger(error?.status) ? error.status : undefined;
      return reply(status === undefined || status === 2 ? 503 : 422, {
        error: 'Apple verification failed', ...(status === undefined ? {} : { status }),
      });
    }
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  createVerificationServer({ secret: process.env.APPLE_VERIFIER_SECRET })
    .listen(Number(process.env.PORT || 8080), '0.0.0.0');
}
