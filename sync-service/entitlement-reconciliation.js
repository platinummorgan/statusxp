export function createEntitlementReconciliationPoller({
  enabled = false, supabaseUrl, serviceRoleKey, fetchFn = fetch, logger = console,
}) {
  let running = false;
  let stopped = false;
  let controller;
  const tick = async () => {
    if (!enabled || !supabaseUrl || !serviceRoleKey || stopped || running) return;
    running = true;
    try {
      // Each invocation claims one job. Bound the batch so sync work can continue.
      for (let i = 0; i < 5 && !stopped; i++) {
        const requestController = new AbortController();
        controller = requestController;
        const timeout = setTimeout(() => requestController.abort(), 90_000);
        timeout.unref();
        try {
          const response = await fetchFn(new URL('/functions/v1/reconcile-premium-entitlements', supabaseUrl), {
            method: 'POST', headers: { Authorization: `Bearer ${serviceRoleKey}`, apikey: serviceRoleKey },
            signal: controller.signal,
          });
          if (!response.ok) throw new Error('Reconciliation endpoint unavailable');
          const result = await response.json();
          if (result.processed === 0) break;
          if (result.processed !== 1) throw new Error('Invalid reconciliation response');
          if (result.retryScheduled || result.leaseLost) logger.warn('Entitlement check retained for retry');
        } finally { clearTimeout(timeout); controller = undefined; }
      }
    } catch {
      if (!stopped) logger.warn('Entitlement reconciliation unavailable; durable jobs retained');
    } finally { running = false; }
  };
  return { tick, stop: () => { stopped = true; controller?.abort(); } };
}

export function startEntitlementReconciliationWorker(options) {
  if (!options.enabled) return () => {};
  const poller = createEntitlementReconciliationPoller(options);
  const timer = setInterval(() => { void poller.tick(); }, 60_000);
  timer.unref();
  void poller.tick();
  return () => { clearInterval(timer); poller.stop(); };
}
