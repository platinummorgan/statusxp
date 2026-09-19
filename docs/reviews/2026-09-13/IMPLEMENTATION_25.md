# Batch 25 — Co-op session rescheduling

Implemented locally on 2026-09-13. No production migration or deployment.

Hosts can choose **Change session time** on active request details, select a future date/time in their device timezone, or switch to flexible timing. Accepted players and request status remain unchanged. The editor explains that hosts must contact their partners; saving does not send notifications or assert renewed attendance. Failed saves retain the selected time for retry. Completed, cancelled, and closed requests cannot be rescheduled.

Session summaries show when timing changed and ask participants to check the plan with their partners. The timestamp is visible wherever the shared summary appears, including confirmed sessions. This is a persistent change label, not an unread notification or participant acknowledgment system.

The authenticated owner-only RPC locks the request and checks its schedule revision before changing it. A stale editor cannot overwrite a different newer plan. Repeating an already successful save with the same time is harmless. Times must be in the future with a valid UTC offset; flexible timing clears both fields. A database trigger owns revision/change timestamps for all schedule updates, including expired-schedule clearing through reconfirmation. New requests cannot forge change history; historical rows start at revision zero without an invented change time.

Validation:

- Full Flutter suite: 119 passed, 9 existing platform-specific skips.
- Three new widget/model tests cover past-time rejection, flexible timing, retry with preserved input, and visible change metadata after serialization.
- Isolated PostgreSQL `test/coop_reschedule.sql` passed migration reapplication, owner-only access, forged initial metadata reset, accepted-team preservation, duplicate saves, stale revisions, invalid times/offsets, flexible clearing, helper visibility, and completed-request rejection. Fixture rows rolled back and the database server was stopped afterward.
- `flutter analyze --no-pub`: no issues after fixing one brace-style lint.
- `flutter build web --release --no-pub --no-tree-shake-icons`: passed. Existing optional Wasm compatibility warnings remain; the JavaScript build succeeds.

Release: review and manually apply `supabase/migrations/20260913200000_coop_rescheduling.sql` after batches 21–24, then deploy the client with the coordinated rollout requirements from batch 22. Do not use `supabase db push --linked`. Run the SQL fixture against the isolated co-op database prepared by earlier batches. Controlled REST/browser verification, including two host editors and participant refresh after a schedule change, remains required before release. Prior batch 24's local REST setup rejection remains unresolved; this batch did not retry that setup.

SX-040 remains open for full end-to-end validation and deployment. The next product milestone is consistent visibility of existing next-action, challenge, and recap features on desktop and mobile.
