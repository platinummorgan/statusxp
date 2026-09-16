# Store update purchase and restore validation

## Current status

Apple Production and Sandbox notifications, and a Google Play Console test, have reached the live backend. These tests establish delivery, not real purchase or restore behavior.

**Google device test now verified:** on September 15 the owner reported restore success. Backend inspection at 21:34 UTC showed one verified Google monthly test subscription (`is_test=true`), a binding to the intended account, canceled state with future expiry at 21:38:42 UTC, and effective Premium source Google while developer Premium was disabled. Protected developer Premium was restored at 21:35 UTC; owner/admin access and non-expiring developer entitlement were verified. This establishes test-purchase verification, canceled-but-unexpired entitlement and reported restore success. It does not establish every renewal/expiry case, repeated restore behavior, build-96 cancellation UI behavior, or Apple purchase restoration. Audit files `owner_restore_observed.json` and `owner_premium_test_restored.json` are outside the repository; the active-test marker is closed.

September 15 client fixes:
- Restore remains available on the mobile membership screen for existing premium members.
- Restore waits for server verification and reports this restore session's outcome. Existing developer/Twitch/other premium cannot produce a false restore success.
- Enumeration and verification errors remain retryable; server verification waiting is bounded to 45 seconds. Reopening the membership page does not add duplicate purchase listeners.
- Android AI-credit packs are consumed only after verified credit delivery. Consumption errors remain retryable and do not trigger a second acknowledgement. iOS completion remains after delivery.

Validation: after the checkout correction, the full suite passed 171 tests with 9 existing skips; an additional reopened-screen regression subsequently passed. After the SafeArea change, all six membership widget tests passed again and targeted analysis was clean. Android release builds passed. **Current internal release is 1.1.18+97; production remains build 92.** Project `pubspec.yaml` remains **1.1.18+93**; Android test builds used explicit `--build-number` overrides. Future uploads must use an unused number above 97. An iOS archive still needs Mac/Xcode or the established Apple build pipeline; this workspace is Windows.

Current Android artifact: `build/app/outputs/bundle/release/app-release.aab`, build **97**. `jarsigner -verify` passed, Google accepted the upload, and its returned SHA-256 matched the local bundle. Upload/release audit: `D:/.tmp/statusxp-premium-audit-20260914/play_internal_97_release_20260915.json`; a fresh API read confirmed internal build 97 completed and production build 92 completed. This supersedes the earlier artifact audits. Client changes are available to the existing Android internal testers; no production or Apple update was submitted. Owner confirmed the build-97 phone navigation spacing fix succeeded. The separate checkout cancellation UI retest remains unconfirmed.

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
