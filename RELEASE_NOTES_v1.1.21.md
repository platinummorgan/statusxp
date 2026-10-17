# StatusXP 1.1.21 (104)

## Google Play release notes

Get into StatusXP faster with quicker startup and dashboard loading. My Games now loads a smaller recent-games page, keeps saved games visible, and automatically retries connection failures. App achievements now update reliably after syncs. PlayStation sync uses the correct trophy terminology, and PlayStation, Xbox, and Steam instructions are clearer and easier to read. Account reconnection checks apply only to linked platforms.

## Changes

- Render the app before optional services finish starting, show saved dashboard data, and refresh automatically after sync and app resume.
- Load only the dashboard's first 20 games through a dedicated database function. Keep the full library accessible through View All Games.
- Cache private libraries separately for each account and automatically retry failed loads without requiring manual refreshes.
- Reconcile app achievements on the server, process completed syncs through a durable queue, and update the achievement screen automatically.
- Improve sync instructions, contrast, progress visibility, and PlayStation trophy wording.
- Preserve completed reconnection checks while rechecking the same account and retain platform-specific account requirements.

## Validation

- Full Flutter suite: 248 passed, nine existing skips.
- Signed Android App Bundle and release web build passed. Android upload certificate matches build 103.
- Targeted analysis: no issues. Full analysis reports one existing style info in `test/platinum_card_preview_test.dart:37`.
- Database regression checks passed for all 133 app achievement rules, authorization, idempotence, and sync queue recovery.
- Dashboard database checks passed for detailed response compatibility, owner access, and bounded results, including the two largest libraries.
- Dashboard query sample for the owner's account: approximately 34 ms database execution; deployed API smoke check returned 20 detailed games successfully.

## Release status

- Production database changes are applied and archived under `supabase/migrations/_manual_production_archive/`.
- Android submitted to Google Play production on October 17, 2026, with review requested. Google accepted build 104, verified its SHA-256, and validated the release. A fresh API read confirmed production references build 104; this does not establish review approval or public availability.
- Bundle SHA-256: `3716fbf9f187c57bec57144e465b303926eaef038f2357a36d22477546874509`.
- Source pushed to GitHub main. Production web deployment `dpl_9maNq9dKfRtdKUbbxKidY6nhqxc3` is ready. Live checks at `https://statusxp.com` returned version 1.1.21/build 104, HTTP 200 for the app and bootstrap, and the new dashboard and achievement RPCs in the compiled client.
- iOS source is included; a Mac archive and App Store submission remain necessary.
