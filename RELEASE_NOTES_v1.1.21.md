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
- Targeted analysis: no issues. Full analysis reports one existing style info in `test/platinum_card_preview_test.dart:37`.
- Database regression checks passed for all 133 app achievement rules, authorization, idempotence, and sync queue recovery.
- Dashboard database checks passed for detailed response compatibility, owner access, and bounded results, including the two largest libraries.
- Dashboard query sample for the owner's account: approximately 34 ms database execution; deployed API smoke check returned 20 detailed games successfully.

## Release status

- Production database changes are applied and archived under `supabase/migrations/_manual_production_archive/`.
- Android, web, and GitHub publication results will be recorded after verification.
- iOS source is included; a Mac archive and App Store submission remain necessary.
