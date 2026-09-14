import test from 'node:test';
import assert from 'node:assert/strict';
import { createEntitlementReconciliationPoller } from './entitlement-reconciliation.js';
const base = { enabled: true, supabaseUrl: 'https://test.invalid', serviceRoleKey: 'fixture-secret', logger: { warn() {} } };
const reply = body => ({ ok: true, json: async () => body });
test('disabled or missing configuration makes no provider requests', async () => {
  for (const changes of [{ enabled: false }, { serviceRoleKey: '' }, { supabaseUrl: '' }]) {
    let calls = 0;
    await createEntitlementReconciliationPoller({ ...base, ...changes, fetchFn: async () => { calls++; } }).tick();
    assert.equal(calls, 0);
  }
});
test('poller authenticates requests, stops when idle and bounds nonempty batches', async () => {
  let calls = 0;
  const poller = createEntitlementReconciliationPoller({ ...base, fetchFn: async (url, options) => {
    assert.equal(url.pathname, '/functions/v1/reconcile-premium-entitlements');
    assert.equal(options.headers.Authorization, 'Bearer fixture-secret');
    assert.ok(options.signal); calls++; return reply({ processed: 1 });
  } });
  await poller.tick(); assert.equal(calls, 5);
  calls = 0;
  await createEntitlementReconciliationPoller({ ...base, fetchFn: async () => { calls++; return reply({ processed: 0 }); } }).tick();
  assert.equal(calls, 1);
});
test('overlapping ticks do not start another batch and stop aborts pending requests', async () => {
  let finish; let signal; let calls = 0;
  const poller = createEntitlementReconciliationPoller({ ...base, fetchFn: async (_url, options) => {
    calls++; signal = options.signal; return await new Promise(resolve => { finish = resolve; });
  } });
  const first = poller.tick(); await poller.tick(); assert.equal(calls, 1);
  poller.stop(); assert.equal(signal.aborted, true); finish(reply({ processed: 1 })); await first;
  await poller.tick(); assert.equal(calls, 1);
});
test('transport failures are redacted and a later tick can retry', async () => {
  const warnings = []; let calls = 0;
  const poller = createEntitlementReconciliationPoller({ ...base, logger: { warn: message => warnings.push(message) }, fetchFn: async () => {
    calls++; if (calls === 1) throw new Error('fixture-secret and private payload'); return reply({ processed: 0 });
  } });
  await poller.tick(); await poller.tick(); assert.equal(calls, 2);
  assert.equal(warnings.length, 1); assert.ok(!warnings[0].includes('fixture-secret'));
});
