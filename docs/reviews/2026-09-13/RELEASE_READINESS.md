# Release readiness — local improvements

Updated 2026-09-13. Nothing in batches 20–31 has been deployed or migrated to production by this work. The working tree also contains earlier backend/auth/payment changes; do not treat a push of the entire tree as a frontend-only release.

## Verified locally

- [x] Latest application validation: 136 Flutter tests passed, 9 existing platform-specific skips; analysis clean; release JavaScript web build passed (batch 31).
- [x] Local static server returns 200 for home, catalog and co-op deep links, bootstrap JavaScript, a font, and an image with appropriate local MIME types.
- [x] Guest catalog deep link renders and displays results in Chrome. One Steam CDN cover failed CORS and rendered a fallback; no claim of all artwork working.
- [x] Removed the Vercel `/assets/(.*)` rule that forced every asset to `application/json`. Keep the two explicit app-association JSON rules. JSON config parses; deployed MIME verification remains required. See [Vercel header configuration](https://vercel.com/docs/project-configuration/vercel-json) and [response headers](https://vercel.com/docs/headers/response-headers).
- [x] Co-op database fixtures and widget journeys recorded in batches 21–25; picker range/order requests checked with HTTP mocks in batch 31.

## Before release

- [ ] Select and review the exact release diff, including new/untracked source files and dependencies. Exclude unrelated generated files and tracked `sync-service/node_modules` churn. Inventory earlier batches' backend/client dependencies before choosing a frontend subset.
- [ ] Verify signed-in local/staging desktop and mobile flows: dashboard recommendations, another/reset, challenges, recap; Flex Room populated/empty rooms, editing, failed saves, recent highlights, picker search/paging; co-op browsing and activity.
- [ ] Verify catalog search/filtering and representative artwork hosts; record the Steam CORS failure rather than counting fallback rendering as successful image delivery.
- [ ] Compare the same-account Flex Room network trace with the recorded baseline. Do not substitute shell LCP for usable canvas content.
- [ ] Inventory live co-op schema, grants, policies and applied migration ledger; review differences and recovery/backup procedure.
- [ ] Apply co-op migrations in staging in the order below, then run the real REST/browser journey with controlled host/helper accounts: create → offer → accept → contact → reschedule → complete → private feedback. No real offers/messages should be sent as a test.
- [ ] Verify helper/outsider privacy, duplicate offers, capacity limits, stale schedule edits, completion retries, and account switching in the actual API environment.
- [ ] Prepare coordinated client/database rollout. Batch 22 revokes direct request/response updates used by older clients; a web-only update does not retire old mobile clients. Resolve compatibility/upgrade handling before production migration.
- [ ] Create a concrete release diff and deployment/migration plan for approval. No push, deployment, or production migration is authorized merely by this checklist.
- [ ] After release, verify Vercel deep links, font/image/JSON/JavaScript MIME types, refreshed client assets, and signed-in smoke checks. Record deployed revision and migration versions here.

## Co-op migration order

1. `20260913120000_coop_participant_history.sql`
2. `20260913140000_coop_session_planning.sql`
3. `20260913160000_coop_request_confirmation.sql`
4. `20260913180000_coop_feedback_outcomes.sql`
5. `20260913200000_coop_rescheduling.sql`

Review and apply these manually after reconciling live state; do not use `supabase db push --linked`. Earlier backend batches have separate dependencies and release requirements. The prior automatic approval rejection of the bundled local REST-server setup remains recorded in batch 24; this check did not retry it or validate that server.

The preview at `http://127.0.0.1:4173/` serves the latest local build. It is a local frontend, not an isolated staging backend. At review time the user's local tab was signed out, so signed-in checks remain incomplete. The live browser session was not copied to localhost.

## GitHub handoff — 2026-09-14

The user authorized committing and pushing all project changes. Pushed implementation commit e0c183c; remote hash verified. Branch: `release/app-improvements-2026-09-14`. This includes earlier backend/auth/payment batches as well as the product improvements. The existing canonical-achievement PR is left untouched. Production migration, main-branch merge, and deployment checks above remain open. Sync-service tests rerun for this handoff: 21 passed. The latest Flutter validation remains 136 passed with 9 skips, clean analysis and a successful release web build. Local dependency folders and tool temporary state are not part of this handoff.
