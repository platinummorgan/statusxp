# Batch 22 — Session planning and reliable partner confirmation

Implemented locally on 2026-09-13. No production migration, deployment, or real player interaction.

Players creating a request can now specify 1–7 additional players and an optional start date/time. The picker uses the device's time zone for the chosen date; UTC is stored along with that date's host offset. Cards and details show the viewer's local time with an explicit UTC offset and identify the host's scheduling offset. Flexible availability remains available. Existing requests default to one additional player and no fixed start time. Recurring schedules, selecting another named time zone, and rescheduling are not included in this batch.

Acceptance now uses one owner-checked database operation. It locks the parent request, checks remaining capacity and the offer's state, confirms the helper, and marks the request assigned only when all requested places are filled. Remaining pending offers then become declined. Retrying the same accepted offer is harmless; two different simultaneous acceptances cannot overfill a session. Historical duplicate rows are preserved but cannot count the same helper twice.

New offer inserts lock the same request and reject duplicate offers, self offers, forged status/identity, and offers on closed requests. The database also validates group size, complete scheduling fields, and future start times for newly created requests. Completion/cancellation are owner-checked transactions that update the request and outstanding offers together. Completion records accepted helpers as completed. The prior request status constraint omitted `completed`; the migration now explicitly supports it along with existing legacy states.

Direct client UPDATE privileges on requests/responses are removed in favor of the acceptance, decline, and finish RPCs. Request creation remains restricted to the caller's own open request. The client no longer performs separate acceptance and assignment writes; details refresh both request and offer state after finishing a session, and display completed helpers correctly.

Validation:

- `flutter analyze --no-pub`: no issues.
- Full Flutter suite: 104 passed, 9 existing platform-specific skips. New tests cover legacy/model round-tripping, fractional UTC offsets, single-RPC state changes, flexible request creation, and date/time/group selection on a 390-pixel screen. Existing hub tests also pass with the session summary.
- `flutter build web --release --no-pub --no-tree-shake-icons`: passed. Existing optional Wasm compatibility warnings remain; the standard JavaScript build succeeds.
- PostgreSQL 18 fixture passed migration reapplication, preservation of historical duplicates, ownership and direct-write boundaries, capacity, same-offer retries, same-helper duplication, completion, terminal-state protection, future-time and group-size validation.
- Two independent database connections competing for one opening produced one acceptance and one rejected attempt. A forced request-update failure rolled back the preceding offer acceptance. Two concurrent inserts by the same helper produced one offer and one duplicate rejection. Temporary database server stopped after verification.

Database reproduction: use a fresh isolated database named `statusxp_coop_sessions_test`, with Supabase-style `authenticated` and `anon` roles. Run `test/coop_session_planning.sql` with `psql -v ON_ERROR_STOP=1`. Run `coop_session_race_a.sql` and `coop_session_race_b.sql` concurrently, then `coop_session_race_verify.sql`. Run `coop_offer_race_a.sql` and `coop_offer_race_b.sql` concurrently, then `coop_offer_race_verify.sql`. One competing command in each pair is expected to fail; the verification files assert the final state. Every fixture guards the database name.

Release requires coordinating migration `20260913140000_coop_session_planning.sql` with the new client after batch 21's participant-history migration. Older clients still use direct state writes and will lose that ability after the privilege change; plan a client upgrade/maintenance window rather than applying this independently. Inspect live policy, column-grant, and schema differences first, then apply the reviewed migration manually under the repository migration policy. Do not use `supabase db push --linked`. Staging checks with real PostgREST and two controlled accounts, plus named-zone/DST device checks, remain required before release.

Remaining co-op work: game artwork, request freshness/reconfirmation, a more focused confirmed-session presentation, feedback/outcome tracking, rescheduling, and live end-to-end validation. Overall SX-040 remains in progress.
