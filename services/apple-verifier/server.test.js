import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, sign, X509Certificate } from 'node:crypto';
import { createVerificationServer } from './server.js';
import { verifyApplePayload } from './verifier.js';
import { appleRootsBase64 } from './apple-roots.js';

const secret = 'test-apple-verifier-secret-32-characters';
async function start(t, verify) {
  const server = createVerificationServer({ secret, ...(verify ? { verify } : {}) });
  server.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => { server.closeAllConnections(); server.close(resolve); }));
  return `http://127.0.0.1:${server.address().port}`;
}
const body = { kind: 'notification', sandbox: false, signedPayload: 'fixture' };
const post = (url, data = body, token = secret) => fetch(`${url}/verify`, {
  method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
  body: JSON.stringify(data),
});

test('missing verifier authentication prevents startup', () => {
  for (const value of [undefined, '', 'short', ' '.repeat(40)]) assert.throws(() => createVerificationServer({ secret: value }));
});

test('unauthenticated, invalid and oversized requests never reach Apple verification', async (t) => {
  let calls = 0;
  const url = await start(t, async () => { calls++; return {}; });
  assert.equal((await post(url, body, 'wrong')).status, 401);
  for (const data of [{}, { ...body, kind: 'constructor' }, { ...body, sandbox: 'false' }]) assert.equal((await post(url, data)).status, 400);
  assert.equal((await post(url, { ...body, signedPayload: 'x'.repeat(140000) })).status, 413);
  assert.equal(calls, 0);
});

test('verified responses preserve the requested verification kind and environment', async (t) => {
  const calls = [];
  const url = await start(t, async (request) => { calls.push(request); return { verified: true }; });
  for (const kind of ['notification', 'transaction', 'renewal']) {
    for (const sandbox of [false, true]) {
      const response = await post(url, { ...body, kind, sandbox });
      assert.equal(response.status, 200);
      assert.deepEqual(await response.json(), { payload: { verified: true } });
    }
  }
  assert.equal(calls.length, 6);
});

test('verification failure and provider outage fail closed without leaking error contents', async (t) => {
  for (const [status, expected] of [[1, 422], [2, 503], [undefined, 503]]) {
    const url = await start(t, async () => { throw Object.assign(new Error('private payload'), { status }); });
    const response = await post(url);
    assert.equal(response.status, expected);
    assert.ok(!(await response.text()).includes('private'));
  }
});

test('bundled Apple roots have valid self-signatures and CA constraints in Node', () => {
  assert.equal(appleRootsBase64.length, 3);
  for (const root of appleRootsBase64) {
    const cert = new X509Certificate(Buffer.from(root, 'base64'));
    assert.match(cert.subject, /Apple/);
    assert.equal(cert.ca, true);
    assert.equal(cert.verify(cert.publicKey), true);
  }
});

test('real Apple library rejects attacker signatures and forged chains for every payload kind', async () => {
  const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  for (const x5c of [undefined, Array(3).fill(appleRootsBase64[2])]) {
    const header = Buffer.from(JSON.stringify({ alg: 'ES256', ...(x5c ? { x5c } : {}) })).toString('base64url');
    const payload = Buffer.from(JSON.stringify({
      notificationType: 'TEST', notificationUUID: '00000000-0000-4000-8000-000000000001',
      version: '2.0', signedDate: Date.now(), data: { bundleId: 'com.statusxp.statusxp', environment: 'Sandbox' },
    })).toString('base64url');
    const input = `${header}.${payload}`;
    const signature = sign('sha256', Buffer.from(input), { key: privateKey, dsaEncoding: 'ieee-p1363' }).toString('base64url');
    for (const kind of ['notification', 'transaction', 'renewal']) {
      await assert.rejects(() => verifyApplePayload({ kind, sandbox: true, signedPayload: `${input}.${signature}` }));
    }
  }
});
