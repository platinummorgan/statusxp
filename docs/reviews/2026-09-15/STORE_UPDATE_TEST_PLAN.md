# Store update purchase and restore validation

## Current status

Apple Production and Sandbox notifications, and a Google Play Console test, have reached the live backend. These tests establish delivery, not real purchase or restore behavior.

**Google device test now verified:** on September 15 the owner reported restore success. Backend inspection at 21:34 UTC showed one verified Google monthly test subscription (`is_test=true`), a binding to the intended account, canceled state with future expiry at 21:38:42 UTC, and effective Premium source Google while developer Premium was disabled. Protected developer Premium was restored at 21:35 UTC; owner/admin access and non-expiring developer entitlement were verified. This establishes test-purchase verification, canceled-but-unexpired entitlement and reported restore success. It does not establish every renewal/expiry case, repeated restore behavior, build-96 cancellation UI behavior, or Apple purchase restoration. Audit files `owner_restore_observed.json` and `owner_premium_test_restored.json` are outside the repository; the active-test marker is closed.

September 15 client fixes:
- Restore remains available on the mobile membership screen for existing premium members.
- Restore waits for server verification and reports this restore session's outcome. Existing developer/Twitch/other premium cannot produce a false restore success.
- Enumeration and verification errors remain retryable; server verification waiting is bounded to 45 seconds. Reopening the membership page does not add duplicate purchase listeners.
- Android AI-credit packs are consumed only after verified credit delivery. Consumption errors remain retryable and do not trigger a second acknowledgement. iOS completion remains after delivery.

Validation: after the checkout correction, the full suite passed 171 tests with 9 existing skips; an additional reopened-screen regression subsequently passed. After the SafeArea change, all six membership widget tests passed again and targeted analysis was clean. Android release builds passed. The AI credit shop update subsequently passed the full suite (180 tests, 9 existing skips) and targeted analysis. The trophy restoration subsequently passed 184 tests with 9 existing skips. The full-width formatting correction passed 185 tests with 9 existing skips. **Current internal release is 1.1.18+100; production remains build 92.** Project `pubspec.yaml` is now the next candidate, **1.1.19+102**. An iOS archive still needs Mac/Xcode or the established Apple build pipeline; this workspace is Windows.

The existing Android artifact at `build/app/outputs/bundle/release/app-release.aab` is the previously verified build **100** and must not be treated as the 1.1.19+102 candidate. `jarsigner -verify` passed, Google accepted that earlier upload, and its returned SHA-256 matched the local bundle. Upload/release audit: `D:/.tmp/statusxp-premium-audit-20260914/play_internal_100_release_20260916.json`; a fresh API read confirmed internal build 100 completed and production build 92 completed. Client changes are available to the existing Android internal testers; no production or Apple update was submitted. The owner directed that the new Android bundle must not be built yet.

## September 19 release reconciliation

- Candidate source version set to **1.1.19+102**. No Android candidate bundle was produced, uploaded, or released.
- Audited all live Supabase Edge Functions against repository source. All 36 tracked functions now match live exactly. Two older Steam OpenID functions remain live-only and unreferenced by current or September 2 web/app source; they were left untouched pending an explicit retire-or-restore decision.
- Deployed the current AI guide contract and restored its quota/reservation database functions. A temporary-account live request returned JSON, produced a guide, recorded one successful request and one daily-free use, and was removed afterward.
- Reconciled all six genuinely missing database migrations: the durable leaderboard queue and five co-op lifecycle migrations. Preserved owner-scoped direct updates for production build 92 during the store transition.
- Live co-op smoke test passed create, offer, accept, unauthorized-user rejection, reschedule, complete, private per-user feedback, and build-92 direct-update compatibility. Both temporary accounts were removed.
- Verified all 102 repository migrations now match the remote migration ledger; prior manually applied Premium/store migrations were marked applied only after their expected live tables, RPCs, columns, and earlier rollout behavior were confirmed.
- Deployed the current sync service to Railway as deployment `2a676e3e-662f-488a-8b14-0ed3624e1a0d`. Deployment succeeded and `/health` returned `status: ok`; startup logs confirmed required configuration presence without exposing values.
- Validation: 106 Deno tests passed, 21 sync-service tests passed, 185 Flutter tests passed with 9 existing skips, and Flutter analysis reported no issues.
- Public web remains on its September 2 production deployment until a separate web build and deployment is completed. App Store and Google Play production binaries remain unchanged.

## Device and account prerequisites

- Android phone connected September 15: Samsung SM-S926U, Android API 36. Installed StatusXP is Play-distributed version 1.1.18, build 93. Device identifiers stay outside the project documentation.
- Compared installed and local APK signing certificates: Play app signing differs from the local upload key, so the local APK cannot update this installation directly. No uninstall or data clearing was performed.
- Play API inventory confirmed production build 92 and internal testing build 93; highest uploaded bundle was 93. Built a new 1.1.18+94 bundle using `--build-number=94`; `pubspec.yaml` remains at 93. The current AAB path now contains build 94, superseding the build-93 artifact described above.
- Build 94 uploaded successfully; Google returned a matching bundle SHA-256. Saved an internal-track **draft**, retaining the existing completed build 93 and all other tracks. Production remains on build 92. No test or production rollout was performed.
- Downloaded Google's generated universal APK for build 94, verified its signature matches the phone's installed app, and installed it with `adb install -r`. Confirmed version 1.1.18/build 94 and launched StatusXP. No uninstall or data clearing was performed. This is a USB installation of a Google-signed draft, not a Play Store update; Play billing availability and real restoration still need device validation.
- Store ledger baseline before launching build 94: zero purchase events. User prompted to open membership and report the exact Restore Purchases result. Backend verification is pending; protected owner premium alone is not evidence of restored billing.
- Upload, draft and generated-APK audit metadata are stored outside the repository in `D:/.tmp/statusxp-premium-audit-20260914/`. Source version remains 93; future builds need an explicit unused build number, and build 94 is now occupied.
- Follow-up startup check: build 94 exits itself and Android reports the launch resolving to Google Play (`com.android.vending`), consistent with Play installation protection on the USB-installed draft. The app is **not ready for the restore test yet**. No crash was recorded for these exits. Do not treat the successful package installation as successful app startup.
- Requested authorization to release the existing build-94 draft to the existing internal tester audience, then install/update through Google Play. Awaiting approval; production remains build 92. No protection bypass, uninstall, or data clearing was attempted.
- Subsequent authorization received: **Release build 94 to internal testers**. Committed the internal release with status `completed`; a fresh API read confirmed internal build 94 completed and production build 92 completed. Existing tester configuration and other tracks were preserved. Opened the Play listing on the connected phone; store installation/update and startup confirmation remain pending. Release audit: `play_internal_94_release_20260915.json` outside the repository.
- User then confirmed the app requested an update but reported it was not installed from Google Play. Built and released the same changes as **build 95** so the store can offer a version newer than the USB-installed build 94. Fresh Play API read confirmed internal build 95 completed, production build 92 completed. Reopened its Play listing; awaiting the user's store update and successful startup. No USB installation of build 95 was performed.
- First investigate the owner's existing Google subscription using the same Google Play account and StatusXP login. Do not buy another subscription just to restore it.
- Test new purchases with a separate controlled StatusXP account without protected developer/admin premium. The owner's premium flag cannot demonstrate that a store purchase grants access.
- For new Android test purchases, use a Play license tester and confirm the checkout shows a test payment method. An internal testing track by itself does not prevent real charges. [Google testing guidance](https://developer.android.com/google/play/billing/test).
- For iOS, use a sandbox tester/TestFlight as appropriate. Sandbox TEST notifications are allowed, while general Sandbox subscription notifications remain guarded. Plan isolation and controlled tester access before enabling lifecycle delivery. [Apple sandbox guidance](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox).

## Checklist

Build 97 layout correction: the owner reported Restore Purchases under the phone's Back/Home buttons. The membership body now uses SafeArea for bottom/side system insets, keeping the app bar's existing top-inset handling. Six existing membership widget tests passed and targeted analysis was clean. Owner subsequently confirmed success on the phone: Restore Purchases is accessible above the navigation controls. Gesture-navigation and rotation variants were not separately reported.

Canceled-checkout fix prepared for build 96: user reported backing out of payment methods/checkout displayed a success/processing message and left Subscribe spinning. Root cause was using checkout launch success followed by a 12-second entitlement poll, plus a nonreactive service busy flag. The new purchase flow tracks actual cancel/pending/error callbacks and verified delivery; only verified delivery and finalization can report purchase success. It accepts blank-product Play cancellation/error callbacks, ignores unrelated restores, clears busy state on failure/rejection/timeout, and updates a reopened membership screen. AI packs use the same outcomes. Full suite: 171 passed/9 existing skips; a subsequent reopened-screen regression also passed (all six membership tests passed). Live backend check at 19:46 UTC: owner Premium false, admin true, zero purchase events. The subsequent Google test purchase/restore passed (see Current status); the separate on-device checkout cancellation regression remains unconfirmed.

- [ ] Build 96: back out of payment methods, then cancel the checkout; expect "Purchase canceled.", no success message, and a usable Subscribe button immediately.
- [ ] Repeat checkout/cancel, including leaving and reopening the membership page; no persistent spinner.
- [x] Google license-test purchase and canceled-but-unexpired restore: verified test ledger, intended account binding and effective Google Premium while developer Premium was off.
- [ ] Verify subscription acknowledgement and same-account mobile/web access; complete remaining expiry/renewal checks.

Owner correction and controlled test setup: the owner confirmed he has no paid Google subscription and authorized temporarily disabling his developer Premium to test a license-test purchase, cancellation and restoration. At 16:36 UTC September 15, only `app_access_grants.premium` was set false; owner role and administrative access remain active. Verified effective Premium false and admin access true. Original grant backup: `owner_premium_test_grant_backup.json`; active-test audit: `owner_premium_test_active.json`, both outside the repository. **Completed: protected developer Premium was restored at 21:35 UTC after the successful restore test.** Do not infer billing loss from the earlier empty restore. Before completing checkout, confirm the test-payment notice and test card. Verify purchase delivery first, then cancellation and restore while the test subscription is still unexpired; after expiry, Premium should stay off until the developer grant is restored.

September 15 device result: confirmed installed version 1.1.18/build 95 with installer `com.android.vending`. User opened membership, saw Premium Active, and received **No purchases found for this store account** after restoring. A backend read at 16:33 UTC showed zero store purchase events. App startup/store installation succeeded. The owner later clarified there was no paid subscription to locate; a subsequent controlled Google test purchase/restore passed. Protected developer access must not be counted as store restoration. The empty result does not establish that no historical purchase exists.

- [ ] Confirm Play Console RTDN settings were saved after the successful test message.
- [x] Identify Android store builds, connected Samsung test device and controlled owner test account.
- [ ] Identify Apple test build, iPhone and sandbox account.
- [x] Install Android through Google Play; user confirmed the build-97 navigation spacing fix.
- [ ] Install the iOS candidate through TestFlight.
- [x] Google test subscription restore: user reported success, with verified ledger/binding and Google Premium while the developer grant was off.
- [ ] Apple subscription restore with verified ledger and intended account binding.
- [ ] Restore again: no duplicate grants or credits; state remains consistent after reopening.
- [x] Android empty store account: no false restore success while developer Premium was active.
- [ ] Verification failure/offline: no success or premature completion; retry restores delivery.
- [ ] Complete the remaining new-subscription cases on Apple; verify acknowledgement and same-account mobile/web access on both providers.
- [ ] Pending/declined purchase: premium is not granted before successful verification.
- [ ] Controlled AI pack: exactly one credit grant, Android consumption after grant, duplicate delivery does not grant twice.
- [ ] Renewal/expiration: source-specific state follows the store; another active provider keeps premium enabled. Use test subscriptions, not the owner's live subscription.
- [ ] Wrong StatusXP account: store purchase cannot be reassigned to another account.
- [ ] Apple actual subscription notifications use the supported event format; signed TEST alone does not establish the configured format.
- [x] Google accepted the signed Android bundle; internal release/build 97 and unchanged production/build 92 verified.
- [ ] Build and validate signed iOS archive with an unused Apple build number.

Do not mark purchase/restore cases passed from inspection, unit tests, notification TEST messages, or protected owner premium. Record device/build, account role, provider event, server verification and observed app behavior for completed cases. Keep raw purchase tokens, receipts and personal account identifiers outside this document and repository.


## AI credit shop validation — September 15

The membership page now has **Buy AI Credits** for both Premium and free users. The game achievements toolbar and out-of-credits action open the same shop. Pack balance comes from the authenticated account's credit row because the Premium allowance response omits banked credits. Mobile prices come from store products. Premium remains active throughout this test; packs do not increase daily limits and remain banked while Premium covers guides.

Automated validation: 180 Flutter tests passed, 9 existing skips; targeted analysis clean. New coverage includes Premium navigation, verified delivery and server-balance refresh, cancellation/retry, pending/error/unconfirmed outcomes, duplicate-tap prevention, unavailable products/balance, and large text with a phone navigation inset.

Pending device test:
1. Install internal build **100** through Google Play, then open **Premium > Buy AI Credits**.
2. Record the displayed pack balance. Prior backend baseline was 10.
3. Choose the **20-credit** pack and confirm Google's payment sheet uses **Test card, always approves** before completing it.
4. Confirm one verified success, exactly 20 additional credits, and persistence after closing/reopening the shop. Starting from 10, expect 30.
5. Inspect the backend purchase event for the small pack, test flag and intended account; verify no duplicate delivery on later restore/reopening.
6. Cancel a separate checkout and confirm no success message, no balance change, and an enabled Buy button afterward.

Device completion and backend credit delivery are not yet verified. No real paid pack purchase has been requested.


## September 16 trophy screen regression

The normal game route's earlier inline catalog omitted the original rich trophy presentation and AI/co-op actions. The restored inline list now shares the original card and guide implementation with the legacy trophy screen, including artwork, platform badges, rarity, StatusXP, earned date, Tips/Comments, AI Help and Find Partner. Base Game/DLC sections and native ordering are restored; inline search, filters, hidden reveal, paging and collapse remain.

Validation: 184 Flutter tests passed, 9 existing skips; targeted analysis clean. Tests open AI Help from the actual game overview and assert game/trophy/platform context, check co-op prefill, hidden reveal, DLC grouping, numeric trophy order, later-page artwork/earned dates, and large text at phone width. A local rendered layout was also inspected. No live guide generation or co-op request was sent by these tests.

Build 99 was built, signed and released to existing internal testers. Google returned a matching SHA-256; a fresh API read confirmed internal 99 completed and production 92 completed. Other tracks were unchanged. The owner confirmed the report was from the previous Android test build.

Pending owner check on internal build 99: open a game from My Games, confirm the detailed cards and AI Help are present, open a guide, and return to the same game. AI credit pack purchase/delivery remains pending separately. This change requires a separate web deployment before it appears on the public website.


## September 16 full-width trophy layout correction

The owner clarified with an original-screen reference that the remaining issue was formatting: trophies were squeezed inside a gray outer panel. The canonical game screen now opens directly on the full-width trophy list with a game/platform header, All/Remaining controls, and original dark Base Game/DLC group styling. Search is available beside filters; Game options provides the cover/catalog/progress details and AI credit shop. Both game screen variants now respect system navigation insets. No scoring rules or earned dates were changed.

Validation: 185 Flutter tests passed (9 existing skips), targeted analysis clean. The new full-screen test checks card position/width, first trophy visibility, bottom navigation clearance, search, and return from game details. A rendered screen was compared with the owner's reference. Owner acceptance of this formatting and the separate AI-pack purchase/delivery test remain pending.

Android 1.1.18+100 was signed and released to existing internal testers. Google returned a matching bundle SHA-256; a fresh API read confirmed internal 100 completed and production 92 completed. Other tracks and tester settings were unchanged. Release audit: `D:/.tmp/statusxp-premium-audit-20260914/play_internal_100_release_20260916.json`.


## Direct device UI testing — September 16

The owner requested direct USB installs for UI-only iterations instead of uploading every build to Google Play. Local build 101 adds a compact standalone progress summary above the full-width trophy list. Completion, earned/total and remaining counts are visible without opening Game details. Trophy layout and navigation spacing remain unchanged. Focused layout/action/data tests passed (6 tests), and targeted analysis is clean.

Build 101 is a local APK, not a Play release. The most recently verified Play internal release remains build 100 and production remains build 92. Store purchase testing still requires the appropriate Play-distributed build and test payment configuration; it is separate from this UI iteration. Future Play updates must use an unused build number that also accounts for local installs.

Local APK installed successfully over USB: `build/app/outputs/flutter-apk/app-release.apk`, version 1.1.18+101, ARM64. Device package version and launch were verified; the process remained alive with no crash-buffer entries. No Play upload or uninstall/data-clear operation was performed. The local APK uses the repository release signing configuration; future Play-store testing must account for the different Play app-signing identity. Owner confirmation of the compact progress UI remains pending.
