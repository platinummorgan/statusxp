# Android completion phone check

Checked November 15, 2026 on the connected Samsung SM-S926U running Android 17.

The installed store app has a different signing certificate from the local release build. The test therefore uses a separate `com.statusxp.statusxp.dev` package labeled **StatusXP Test**, built from the current source in the ignored staging directory. The store package and its data remain intact. Production Android application/Firebase configuration was not changed. The user signed into the test application manually; no credentials or sessions were copied between applications.

## Observed results

- Onboarding and sign-in render and the app starts successfully.
- Sign-in persists through an in-place test APK update and process restart.
- Dashboard StatusXP (78,602), Platinums (201), Xbox Mythic unknown state, and Steam verified count (0) agree with backend reads for the signed-in account.
- Backend reports 35 Steam games awaiting membership review. The dashboard now displays **35 PENDING REVIEW** and **SYNC XBOX** correctly.
- Total Completions shows 201 with **verified so far**, reflecting the unknown Xbox count and incomplete Steam membership coverage.
- The Steam all-time row uses **Completions**, and Xbox displays the expected empty-board message while awaiting Mythic-aware syncs.
- Steam weekly/monthly views load and show the completion metric. Navigation returns to the dashboard.
- No Android fatal exception, RenderFlex overflow, rendering-library exception, or missing-plugin exception was found in the test process logs during these checks.

## Correction found on the device

The mobile circle builder ignored the supplied footer meaning, hardcoded AVG/GAME, and parsed the footer's leading number. That mislabeled a pending-review count as an average and hid the Xbox sync prompt. It now renders the platform-provided footer directly, centered and width constrained.

The actual-dashboard regression now checks both sync prompts as well as unknown count dashes. Targeted Dart analysis and all 18 relevant dashboard/startup/Steam/Xbox widget tests passed. Android debug and web release builds passed. The corrected test APK was installed without clearing data; the same display correction was deployed to production web, whose JavaScript hash matches the local release build.

## Limits and follow-up

This is a native UI/live-read smoke test. A new Xbox sync was not initiated, so a populated personal Mythic import and score increase remain untested on this phone. No positive Steam completion is available in this account's currently reviewed coverage; 35 games remain pending membership review. The existing database regressions cover positive awards, rarity weighting and score reconciliation. Production mobile-store rollout remains separate from this isolated test installation.

## Xbox average footer follow-up

At the user's request, the known Xbox footer now mirrors PlayStation with ordinary achievements per tracked game, rounded to a whole number. The connected phone visibly showed **12 AVG/GAME** for 317 achievements across 27 games after the test APK update. Unknown Xbox completion data still uses the sync prompt. All 12 targeted Xbox/dashboard-startup tests and targeted Dart analysis passed. The same UI change is deployed to production web. Native store release remains pending.
