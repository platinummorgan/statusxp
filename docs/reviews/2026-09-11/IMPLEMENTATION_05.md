# Durable leaderboard refresh retries — SX-009

Date: 2026-09-11. Implemented locally. Database migration, Railway deployment, and live verification remain pending.

The PSN, Xbox, and Steam completion paths previously awaited Supabase RPC calls without inspecting their returned `error`. They could print refresh success and mark the sync successful even when the database rejected the refresh.

## Behavior

All three active workers now persist a refresh obligation before attempting the RPC. Xbox and Steam enqueue a per-user StatusXP refresh. PSN enqueues both that refresh and its existing PSN cache refresh. Returned errors and thrown exceptions are failures; success is logged only after both the RPC and queue acknowledgment succeed.

A failed refresh remains queued and propagates an explicit “data saved; leaderboard refresh pending” error through the existing sync error path. If the queue insert cannot be confirmed, the worker reports that retry recording failed and operator recovery is required. It never substitutes an in-memory-only retry. The PSN partial-failure path still attempts refresh, but a refresh failure cannot prevent recording the original sync error or enqueue the same pending-error path recursively.

The process drains up to ten due jobs on startup and every 30 seconds, with one drain running per process. PostgreSQL claims jobs atomically with `FOR UPDATE SKIP LOCKED`. Five-minute leases recover jobs from terminated workers; lease tokens prevent stale workers from acknowledging reclaimed work. Failures use exponential delays starting at 30 seconds, capped at one hour, without a terminal retry limit. Recovery requires the database/RPC and a worker to become available again.

Each sync creates separate obligations, so completion of an older job cannot delete newer work. A crash after refresh but before acknowledgment can execute a refresh again; these cache-recomputation RPCs must remain safe to repeat. The retry worker only refreshes caches and never invokes platform ingestion. If the background worker wins the race to complete a newly inserted job, the foreground path checks its persisted completion instead of reporting a false pending result.

The queue uses RLS, removes client table privileges, and grants its privileged claim/finish functions only to `service_role`. It stores generic failure categories, not raw database error details or credentials.

## Limits

- This is a leaderboard retry queue, not the durable ingestion-job system in SX-017. A crash before the end-of-sync enqueue still follows existing sync recovery behavior.
- Historical sync/profile errors are not rewritten when the background refresh eventually succeeds. They record the original incomplete outcome; inspect the queue to confirm refresh recovery. Do not rerun achievement ingestion just to retry a queued refresh.
- Completed jobs are retained for audit. Establish a retention job for completed rows (for example, 14 days) after choosing the operational retention period. Never purge pending rows as part of that cleanup.
- The PSN cache RPC remains a whole-cache operation. The new queue does not change its existing database implementation or enforce global serialization across separate PSN jobs.

## Migration reconciliation and release order

The existing uncommitted `20260828120000_remove_per_achievement_leaderboard_refresh.sql` was reviewed and left intact. It removes three old triggers on `user_achievements`/`user_progress`; the active sync completion paths still perform the replacement explicit refreshes, now through the durable helper. No duplicate trigger-removal migration was created.

The live read-only trigger metadata query failed again. Production trigger presence and application of that migration remain unverified; a local migration file is not deployment evidence.

1. Verify live schema and trigger status using the existing migration's verification query. Reconcile the migration ledger through the documented manual process; do not `db push --linked`.
2. Manually apply `20260911140000_leaderboard_refresh_jobs.sql` before deploying the worker. Verify table/function privileges and the service-role grants. The existing per-user StatusXP and PSN refresh RPCs must be present.
3. Deploy the `sync-service` changes. Verify queue claiming with controlled staging data, one successful sync per platform, a returned refresh error, a thrown/network failure, and recovery after restarting the worker. Confirm achievement ingestion is not repeated during queue recovery.
4. If the old per-achievement triggers still exist, retire them only after validating the explicit refresh/retry path. If they are already absent, do not recreate them. Verify live scores against source achievements after recovery.
5. Monitor pending job age, attempts, last error, and worker-unavailable logs. Keep queue records/schema during rollback; restoring an old worker pauses retries until a compatible worker returns.

## Validation

The Node suite passes 14 tests, including nine queue/refresh tests for successful PSN obligations, returned and thrown errors, restart recovery, failed queue insertion, lost acknowledgment, another worker owning a job, concurrent background completion, stale acknowledgment, and bounded draining. All changed JavaScript entrypoints pass syntax checks.

The migration applied successfully twice in a disposable local PostgreSQL 18 cluster. SQL assertions verified client permissions, service-role insertion, lease expiry/rotation, stale-token rejection, persisted backoff, completion, and a later sync's independent obligation. Separate PostgreSQL connections verified locked rows are skipped and simultaneous claims assign a job to only one worker. Synthetic fixture data was used; no production writes or real syncs were performed.

Reproducible SQL assertions are in `sync-service/test/leaderboard-refresh-queue.sql`. The concurrency runner requires an isolated database named `statusxp_refresh_test`, fixture roles/schema, and the queue migration. Set `PGHOST=127.0.0.1`, `PGPORT`, `PGUSER`, `PGDATABASE`, and optionally `TEST_PSQL`, then run `node sync-service/test/leaderboard-refresh-concurrency.cjs`. These database tests are deliberately excluded from ordinary `npm test`.

Evidence: [Node tests](refresh-node-tests.txt), [PostgreSQL assertions](refresh-sql-tests.txt), and [concurrent claims](refresh-concurrency-tests.txt). Flutter checks were not repeated because this batch changes only the sync service and database queue.
