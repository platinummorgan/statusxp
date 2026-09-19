# Batch 21 — Co-op hub discovery and activity

Implemented locally on 2026-09-13. No production deployment or real co-op offers.

The generic two-tab list is replaced with a responsive co-op hub: Find partners, My requests, and My offers. Goal cards show the game, achievement, availability, post age, request/offer state, and relevant actions. Desktop uses two columns; phones use one, with wrapping text and controls. Older open posts explicitly suggest checking availability; no online counts or reconfirmation dates are invented.

Request help explains the existing library → achievements → Find Partner flow and provides a Choose a game action. Owner management/deletion is retained. Accepted helpers have a partner-details link, and assigned/matched requests now expose the existing completion action to their owner.

The new service path applies game/achievement search and platform filters on the server before returning a 24-row page. My offers uses the existing request/response relationship and retains each offer's status. Discovery checks the signed-in user's offers for the visible page, so existing offers lead back to their details. This UI check does not replace database duplicate-offer protection, which remains open.

The hub refreshes when returning from details or creation, supports explicit refresh and pull-to-refresh, ignores superseded searches, resets on account changes, and retains earlier pages on pagination failure. Errors offer Retry instead of presenting an empty community. The older service cache API remains for compatibility; the hub uses fresh bounded queries.

Database change: `20260913120000_coop_participant_history.sql` lets a helper revisit a request they offered on after it leaves the public open feed. A narrowly scoped function checks only the caller's own participation and avoids recursive request/response RLS. New offers must be pending, belong to the caller, and target someone else's open request. This prevents using a newly inserted offer to reveal an unrelated closed post. Existing records are preserved.

Validation:

- Full Flutter suite: 100 passed, 9 existing platform-specific skips, including 12 new co-op tests.
- Coverage includes 390/1240 layouts at 1.3 text scale, search debounce/filtering, stale responses, offer status, owner actions, creation guidance, pagination failure/retry, bounded service queries, and honest errors.
- Isolated PostgreSQL 18 fixture passed migration reapplication, helper/owner/unrelated/anonymous visibility, history after completion, response-policy recursion checks, and rejection of self offers, forged acceptance, and offers on closed posts. Fixture: `test/coop_participant_history.sql`. The temporary database server was stopped afterward.
- `flutter analyze --no-pub`: no issues.
- `flutter build web --release --no-pub --no-tree-shake-icons`: passed. The optional Wasm scan still reports existing `dart:html`/`dart:js_util` compatibility warnings; the standard web build succeeded.

Release order: inspect live co-op schema/policies, apply the participant-history migration manually under the repository migration policy, then deploy the Flutter client and verify controlled owner/helper accounts. Do not use `supabase db push --linked`. Existing pending/accepted/declined history and embedded request filtering need a staging/live smoke test; local HTTP mocks validate generated requests, while the SQL fixture validates authorization separately.

Remaining work: artwork, structured time/timezone and participant needs, request reconfirmation, atomic acceptance and database duplicate-offer protection, dedicated accepted-session presentation, feedback/outcome tracking, and full request → offer → acceptance → contact → completion validation. The overall SX-040 checklist stays in progress.
