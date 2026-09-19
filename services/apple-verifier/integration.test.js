import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { createVerificationServer } from './server.js';

// Opt-in: real Apple-signed TEST messages kept outside the repository.
test('real Production and Sandbox TEST messages pass through the authenticated Node service', {
  skip: !process.env.APPLE_TEST_PAYLOAD_DIR,
}, async (t) => {
  const secret = 'local-integration-secret-32-characters';
  const server = createVerificationServer({ secret });
  server.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => { server.closeAllConnections(); server.close(resolve); }));
  const url = `http://127.0.0.1:${server.address().port}/verify`;
  const send = (sandbox, signedPayload, kind = 'notification') => fetch(url, {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${secret}` },
    body: JSON.stringify({ kind, sandbox, signedPayload }),
  });
  for (const environment of ['production', 'sandbox']) {
    const signed = await readFile(join(process.env.APPLE_TEST_PAYLOAD_DIR, `${environment}_apple_test_jws.txt`), 'utf8');
    const sandbox = environment === 'sandbox';
    const result = await send(sandbox, signed);
    assert.equal(result.status, 200);
    const { payload } = await result.json();
    assert.equal(payload.notificationType, 'TEST');
    assert.equal(payload.data.environment, sandbox ? 'Sandbox' : 'Production');
    assert.equal(payload.data.bundleId, 'com.statusxp.statusxp');
    assert.equal((await send(!sandbox, signed)).status, 422);
    assert.equal((await send(sandbox, signed, 'transaction')).status, 422);
    const parts = signed.split('.');
    parts[2] = (parts[2][0] === 'A' ? 'B' : 'A') + parts[2].slice(1);
    assert.equal((await send(sandbox, parts.join('.'))).status, 422);
  }
});
