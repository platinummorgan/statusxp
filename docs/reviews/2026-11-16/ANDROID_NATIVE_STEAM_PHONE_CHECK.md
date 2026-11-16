# Android native Steam completion check

Tested November 16, 2026 on the connected Samsung SM-S926U running Android 17. Updated the existing **StatusXP Test** debug installation (`com.statusxp.statusxp.dev`) in place. The store installation and its data were not replaced, and the test app retained the user's sign-in through both APK updates and restarts.

## Observed on the phone

| Check | Result |
| --- | --- |
| Dashboard StatusXP | **78,720**, exactly matching the live leaderboard cache |
| Total Completions | **203 · verified so far** |
| PlayStation | **201 Platinums**, 31 AVG/GAME |
| Xbox | **0 Mythics**, 12 AVG/GAME |
| Steam | **2 completions**, **13 AWAITING SYNC**, legible without overflow |
| Steam all-time leaderboard | User row shows **2 Completions** |
| Xbox all-time leaderboard | User row shows **0 Mythics**, rather than Gamerscore |
| Playrooms main game page | Native progress **30/30**; earned **All Achievements 100% · 9.31 StatusXP**, **Estimated rarity: 8.50%**, **1× rarity weighting** |
| Rust main game page | Native progress **55/116 (47%)**, with **no completion award** |
| Android/Flutter diagnostics | No fatal exception, unhandled/rendering exception, RenderFlex overflow, missing-plugin exception or PostgREST exception in the final test process logs |

Returned to the dashboard and left the updated test app open on the phone. No Steam/Xbox sync was initiated; the 13 changed memberships still await the user's next normal Steam sync. The reads and UI navigation did not fabricate achievement progress or completion dates.

## Issue found and fixed

The main canonical game route uses `GameOverviewScreen`, while the completion card had only been integrated into the older `GameAchievementsScreen`. Playrooms initially displayed 30/30 without its earned completion explanation.

Added a shared account-aware native award provider/widget at `lib/ui/widgets/game_completion_award.dart` and rendered it in the canonical game page. It reads the native earned award for the current user and exact platform/AppID. A 100% progress percentage alone never grants a badge. Steam fallback versus official-base labels use the persisted rarity source; Xbox uses its native Mythic award. Loading or unavailable metadata does not prevent ordinary achievement browsing.

Rebuilt and reinstalled the debug APK, revisited Playrooms through the real game catalog, and confirmed its live badge and values. Also opened Rust through My Games and confirmed that its old day-one completion no longer appears as an earned badge under the full-set fallback.

## Validation and release

- Nine targeted widget tests passed: three new canonical-page regressions cover official-base, all-achievements and no-award behavior, alongside six existing game-page/achievement-list regressions.
- Targeted Dart analysis found no issues. Android debug and production JavaScript web builds passed.
- The canonical-page badge fix is also deployed to **statusxp.com**, deployment **statusxp-qmls0ezez-michaels-projects-4c786e88.vercel.app**. The live JavaScript returns HTTP 200 and its SHA-256 matches the fixed local build.
- Screenshots, UI hierarchies, build/test output and sanitized process-log counts are retained privately under ignored `.railway-upload/native-steam-phone-20261116/` and adjacent build logs. No phone credentials were read or copied.

This was a native UI/live-read acceptance pass, not a fresh provider-sync test. A positive live Xbox Mythic and a newly completed official Steam base subset remain dependent on suitable real account data. Native store publication and iOS testing remain separate release work. The backend policy and scoring release are documented in [Native Steam completion sets](NATIVE_STEAM_COMPLETION_SETS_RELEASE.md).

## Subsequent user-initiated normal Steam sync

The user then started Steam sync from the phone. Monitored the real provider-to-database path to **success / 100%**, with no reported issue or relink requirement. All 13 changed games were rechecked, reducing awaiting-sync coverage to **zero**. Steam completions remain **two** (Playrooms and The Room); Rust is confirmed incomplete at **55/116** under the current fallback.

The account's **78,720 StatusXP** matches the canonical sum across 400 game/platform entries and the leaderboard cache. Refreshed global rarity now gives Playrooms an 8.7% estimate and 9.25 completion XP; The Room remains 64.9% and 1.00 XP. These replace the earlier pre-sync rarity snapshot, rather than indicating a formula change.

Returned from Steam Sync through Settings to the dashboard and observed **Total Completions: 203**, Steam **2**, the neutral **GAME COMPLETIONS** footer, and removal of both **13 AWAITING SYNC** and **verified so far**. Left the app on this verified dashboard. This completes the normal Steam sync acceptance check; positive Xbox Mythic and newly earned official Steam-base subset checks remain outstanding.
