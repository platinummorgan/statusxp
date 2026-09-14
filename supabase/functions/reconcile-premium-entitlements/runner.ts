export type ReconciliationJob = {
  provider: "apple" | "twitch" | "google" | "stripe";
  subject: string;
  user_id: string;
  lease_token: string;
};
export type ReconciliationDependencies = {
  claim: () => Promise<ReconciliationJob | null>;
  reconcile: (job: ReconciliationJob) => Promise<void>;
  finish: (job: ReconciliationJob, success: boolean) => Promise<boolean>;
};
// One provider lookup per invocation bounds wall time and lease ownership.
export async function runReconciliation(deps: ReconciliationDependencies) {
  const job = await deps.claim();
  if (!job) {
    return {
      processed: 0,
      succeeded: 0,
      retryScheduled: false,
      leaseLost: false,
    };
  }
  let success = false;
  try {
    await deps.reconcile(job);
    success = true;
  } catch { /* Persist a redacted retry below. */ }
  const finished = await deps.finish(job, success);
  return {
    processed: 1,
    succeeded: success ? 1 : 0,
    retryScheduled: finished && !success,
    leaseLost: !finished,
  };
}
