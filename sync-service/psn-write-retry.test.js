import test from 'node:test';
import assert from 'node:assert/strict';
import { retryPsnWrite } from './psn-write-retry.js';

function options(overrides = {}) {
  const waits = [];
  const retries = [];
  return { label: 'Save progress', sleep: async ms => waits.push(ms), onRetry: event => retries.push(event), waits, retries, ...overrides };
}

test('successful write returns data without retry', async () => {
  const opts = options();
  const result = { data: { id: 1 }, error: null };
  assert.equal(await retryPsnWrite(async () => result, opts), result);
  assert.equal(opts.waits.length, 0);
});

for (const error of [
  { message: '<html><title>502 Bad Gateway</title><center>cloudflare</center></html>' },
  { status: 503, message: 'Service unavailable' },
  { message: 'canceling statement due to statement timeout' },
  new TypeError('fetch failed', { cause: new Error('ECONNRESET') }),
]) {
  test(`recovers transient write failure: ${error.message}`, async () => {
    const opts = options();
    let attempts = 0;
    const result = await retryPsnWrite(async () => {
      if (++attempts === 1) {
        if (error instanceof Error) throw error;
        return { error };
      }
      return { data: 'saved', error: null };
    }, opts);
    assert.equal(result.data, 'saved');
    assert.equal(attempts, 2);
    assert.equal(opts.retries.length, 1);
    assert.ok(opts.waits[0] >= 300 && opts.waits[0] < 550);
  });
}

test('persistent gateway failures stop at the configured limit and retain the cause', async () => {
  const opts = options();
  const error = { status: 502, message: 'Bad Gateway' };
  let attempts = 0;
  await assert.rejects(retryPsnWrite(async () => { attempts++; return { error }; }, opts), caught => {
    assert.match(caught.message, /Save progress: Bad Gateway/);
    assert.equal(caught.cause, error);
    return true;
  });
  assert.equal(attempts, 6);
  assert.equal(opts.waits.length, 5);
  assert.ok(opts.waits.every(ms => ms <= 8250));
});

for (const error of [
  { code: '23503', message: 'foreign key constraint violation' },
  { status: 401, message: 'Unauthorized' },
  { status: 403, message: 'Permission denied' },
]) {
  test(`permanent failure is not retried: ${error.message}`, async () => {
    const opts = options();
    let attempts = 0;
    await assert.rejects(retryPsnWrite(async () => { attempts++; return { error }; }, opts));
    assert.equal(attempts, 1);
    assert.equal(opts.waits.length, 0);
  });
}

test('non-transient thrown errors fail immediately with their original cause', async () => {
  const opts = options();
  const error = new Error('invalid payload');
  let attempts = 0;
  await assert.rejects(retryPsnWrite(async () => { attempts++; throw error; }, opts), caught => {
    assert.equal(caught.cause, error);
    return true;
  });
  assert.equal(attempts, 1);
  assert.equal(opts.waits.length, 0);
});
