import { timingSafeEqual } from 'node:crypto';

// Require configuration before accepting requests, including local development.
export function createSyncAuth(secret) {
  if (typeof secret !== 'string' || !secret.trim()) {
    throw new Error('SYNC_SERVICE_SECRET is required to start the sync service');
  }

  const expected = Buffer.from(secret);
  return (req, res, next) => {
    const header = req.headers.authorization;
    const token = typeof header === 'string'
      ? /^Bearer ([^\s]+)$/i.exec(header)?.[1]
      : undefined;
    const received = Buffer.from(token ?? '');
    if (received.length !== expected.length || !timingSafeEqual(received, expected)) {
      // Never log the supplied header or either credential.
      return res.status(401).json({ error: 'Unauthorized' });
    }
    next();
  };
}
