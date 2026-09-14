import test from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import { createSyncAuth } from './auth.js';

test('missing or blank sync secret prevents server initialization', () => {
  for (const secret of [undefined, null, '', '   ']) {
    assert.throws(() => createSyncAuth(secret), /SYNC_SERVICE_SECRET is required/);
  }
});

test('HTTP sync authentication protects operations while allowing health checks', async (t) => {
  const app = express();
  let operations = 0;
  app.get('/health', (_req, res) => res.json({ ok: true }));
  app.post('/sync', createSyncAuth('test-worker-secret'), (_req, res) => {
    operations++;
    res.json({ ok: true });
  });
  const server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  t.after(() => new Promise((resolve) => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}`;

  const health = await fetch(`${url}/health`);
  assert.equal(health.status, 200);
  await health.json();
  for (const header of [undefined, 'Bearer', 'Basic test-worker-secret',
    'Bearer wrong-worker-key', 'Bearer test-worker-secret-extra']) {
    const response = await fetch(`${url}/sync`, {
      method: 'POST', headers: header ? { Authorization: header } : {},
    });
    assert.equal(response.status, 401);
    assert.deepEqual(await response.json(), { error: 'Unauthorized' });
  }
  assert.equal(operations, 0);

  for (const scheme of ['Bearer', 'bearer']) {
    const response = await fetch(`${url}/sync`, {
      method: 'POST', headers: { Authorization: `${scheme} test-worker-secret` },
    });
    assert.equal(response.status, 200);
    await response.json();
  }
  assert.equal(operations, 2);
});
