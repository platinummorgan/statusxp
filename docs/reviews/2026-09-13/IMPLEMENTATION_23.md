# Batch 23 — Artwork, request freshness, and confirmed sessions

Implemented locally on 2026-09-13. No production deployment, migration, or real request mutation.

Co-op cards now include game artwork. Each page uses a single bounded catalog query, deduplicated by platform/game identity. Artwork loads after request content is available, so a delayed or failed catalog/image request does not block browsing or actions. Fixed-size placeholders preserve layout; superseded page artwork cannot replace the current view. Some legacy game IDs may not match the current catalog and will retain the fallback.

Open requests become visibly marked **Needs confirmation** after 30 days without a post/owner confirmation, or when their scheduled time has passed. Owners can use **Still looking** to explicitly confirm the request. The server records `last_confirmed_at`; new inserts cannot supply a forged confirmation timestamp. An expired scheduled time cannot be reconfirmed unchanged: the owner must explicitly accept flexible timing, which clears the scheduled timestamp and its offset together. Future schedules are preserved. The dialog asks owners to notify any confirmed partners if timing changes; the app does not send a notification automatically.

This is a freshness label and owner action, not automatic deletion, expiry, or a claim that a player is online. The existing creation date and feed ordering remain intact. Free-text availability remains as written by the owner.

Request details now lead with a confirmed-session panel when the viewer is the owner or an accepted/completed helper. Owners see deduplicated confirmed-player counts and available platform usernames. Helpers see their own acceptance and the host's contact, without inferring a full team count from the subset of responses they can read. The panel gives a next step for agreeing on timing, supports copying a platform username, and switches to completion history when the goal is done. Missing contact information is stated explicitly. Existing completion controls remain available below.

Validation:

- Full Flutter suite: 112 passed, 9 existing platform-specific skips.
- New coverage: batched artwork identity, slow/failed artwork remaining nonblocking, owner confirmation refresh, freshness/model round-trip, confirmed-player deduplication, helper/outsider visibility, contact presentation, and completed-session copy. Existing mobile/desktop and pagination regressions pass.
- `flutter analyze --no-pub`: no issues.
- Isolated PostgreSQL 18 confirmation fixture passed migration reapplication, owner-only/open-only checks, server-generated confirmation timestamps, direct-update protection, expired-schedule rejection, explicit clearing of both schedule fields, and preservation of future schedules. Database server stopped after testing.
- Desktop fixture layout inspected from a local render. The preview used artwork fallbacks and test fonts; it is not a production screenshot or real account session.
- `flutter build web --release --no-pub --no-tree-shake-icons`: passed. Existing optional Wasm compatibility warnings remain; the standard JavaScript web build succeeds.

Release: after batches 21–22, review and manually apply `supabase/migrations/20260913160000_coop_request_confirmation.sql`, then deploy the client. Retain batch 22's coordinated client/database rollout requirements. Do not use `supabase db push --linked`. Reproduce database checks with `test/coop_request_confirmation.sql` after the isolated session-planning fixture. Verify actual catalog artwork, owner/helper navigation, clipboard handling, reconfirmation, and final completion in staging with controlled accounts before release.

The co-op feature milestone now has local implementations for discovery, requests/offers, scheduling, acceptance, artwork, freshness, and session presentation. Remaining work includes feedback/outcome tracking, rescheduling confirmed sessions, and the controlled full end-to-end/live validation. SX-040 remains in progress.
