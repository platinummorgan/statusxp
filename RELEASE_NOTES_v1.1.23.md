# StatusXP 1.1.23 (106)

## Google Play release notes

Your completions deserve recognition! Rare PlayStation Platinums now earn bonus StatusXP. Xbox Mythics now count toward your score and have dedicated completion rankings. Steam completions use verified base-game sets, or all available achievements when no reliable separation exists. See unified completion counts, clearer rarity estimates, and earned completion badges. Sync your connected accounts to update your progress.

## Changes

- PlayStation Platinum rarity now contributes completion XP, with 5× weighting on the rarity component. Rarer Platinums receive more points; the ordinary trophy formula remains unchanged.
- Add native Xbox Mythic import, estimated rarity points, earned badges, dashboard counts, and all-time/seasonal Mythic leaderboards. A successful Xbox sync is required to establish the current account's Mythic count. Gamerscore remains available as native achievement data.
- Automate Steam completion requirements using native Achievement Sets. Use a verified base-game subset where reliable and otherwise require all available achievements. Include Steam-exclusive requirements and omit explicitly archived requirements when validated native data identifies them.
- Use the same required Steam IDs for native qualification and minimum-rarity estimation, with 1× rarity-component weighting and one completion per AppID. Xbox estimates use required base-game achievement rarity at 5×; PlayStation uses native Platinum rarity.
- Add unified Total Completions alongside Platinums, Xbox Mythics, and Steam Completions. Show unknown sync states accurately and distinguish games awaiting a completion sync from confirmed zero counts.
- Show Base Game 100% or All Achievements 100% and estimated completion XP on the main game page. Preserve the ordinary achievement list when optional award metadata is unavailable.
- Include dashboard loading/cache safeguards and retain the earlier Engagement Hub and large-library reliability improvements already on the release branch.

## Validation and release artifacts

- Full Flutter suite: **282 passed**, nine existing skips.
- Full Flutter analysis: **no issues found**.
- Sync-service suite: **137 passed**.
- Signed production Android App Bundle built successfully with package `com.statusxp.statusxp`, version **1.1.23**, version code **106**. Its JAR signature verifies, and the upload signing certificate matches build 105.
- Upload artifact: `output/release-1.1.23/statusxp-1.1.23-106.aab` (79,053,596 bytes). The bundle and local verification manifest remain outside Git.
- Bundle SHA-256: `ed9a1db66c9c153b32f4e1009a2f3238974be86f2436ba7b1f2e6866be87bb5c`.
- [Google Play copy](docs/google-play/RELEASE_NOTES_1.1.23+106.md) is 424 characters. On November 16, 2026, Google accepted build 106, returned the matching bundle SHA-256, and validated the production release. The production edit was committed with review requested; a fresh API read confirmed production references build 106 and the completion release notes. Google review approval and public availability are not established by the track API's `completed` rollout status.
- [Submission verification](docs/google-play/SUBMISSION_1.1.23+106.json) records the upload, validation, committed edit and fresh production-track read, without credentials.

The native Steam policy, scoring and web/service deployment evidence is in [the implementation record](docs/reviews/2026-11-16/NATIVE_STEAM_COMPLETION_SETS_RELEASE.md), including the [real Android sync acceptance pass](docs/reviews/2026-11-16/ANDROID_NATIVE_STEAM_PHONE_CHECK.md).

## Mac / iOS handoff

The build source is identified by tag `v1.1.23` (commit `46db2cb`); `main` and `release/app-improvements-2026-09-14` carry the release and subsequent submission documentation. From the existing Mac checkout:

```sh
git fetch origin --tags
git switch main
git pull --ff-only origin main
flutter pub get
flutter build ipa --release --build-name 1.1.23 --build-number 106
```

Alternatively, open `ios/Runner.xcworkspace` after Flutter regenerates the iOS build settings and archive with the existing Apple signing configuration. The iOS build/archive must be performed on the Mac; it was not built on Windows.

This source version supplies iOS's version/build through Flutter as well. On the Mac, pull `main`, run `flutter pub get`, then build/archive with the existing iOS configuration. Machine-local signing credentials remain outside Git. Production database migrations in `_manual_production_archive` are already applied; do not reapply them to production as part of an iOS build.
