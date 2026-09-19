import test from 'node:test';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import express from 'express';

test('updated Express parses JSON and nested queries and enforces body limits', async t => {
  const app = express();
  app.use(express.json()); // Match the sync service's default JSON limit.
  app.get('/query', (req, res) => res.json(req.query));
  app.post('/body', (req, res) => res.json(req.body));
  app.use((error, _req, res, _next) => res.status(error.status || 500).json({ error: true }));
  const server = app.listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  t.after(() => new Promise(resolve => server.close(resolve)));
  const url = `http://127.0.0.1:${server.address().port}`;
  const query = await fetch(`${url}/query?filter[platform]=psn&ids[]=one&ids[]=two`);
  assert.equal(query.status, 200);
  assert.deepEqual(await query.json(), { filter: { platform: 'psn' }, ids: ['one', 'two'] });
  const data = { userId: 'fixture', options: { platform: 'steam' }, name: 'ゲーム' };
  const response = await fetch(`${url}/body`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
  });
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), data);
  for (const [body, status] of [['{invalid', 400], [JSON.stringify({ text: 'x'.repeat(110_000) }), 413]]) {
    const rejected = await fetch(`${url}/body`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body,
    });
    assert.equal(rejected.status, status);
    await rejected.json();
  }
});

test('Express qs override safely round-trips untrusted constructor fields', () => {
  const require = createRequire(import.meta.url);
  const requireExpress = createRequire(require.resolve('express'));
  const qs = requireExpress('qs');
  const parsed = qs.parse('item[constructor][isBuffer]=not-a-function', { plainObjects: true });
  assert.doesNotThrow(() => qs.stringify(parsed));
  assert.deepEqual(qs.parse('platform=steam&offset=50'), { platform: 'steam', offset: '50' });
});
