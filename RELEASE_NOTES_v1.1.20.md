# StatusXP 1.1.20 (103)

## Google Play release notes

Celebrate your platinums with personalized share cards. Choose game covers or your own screenshots, add trophy rarity, and share individual platinums or collections. Premium members can create AI artwork for their cards. Find your earned platinums in Menu > Platinum celebrations. This update also improves sync refresh, leaderboard accuracy, account reconnection, and navigation.

## Validation

- Full Flutter suite: 220 passed, 9 platform-specific tests skipped.
- Backend edge tests: 49 passed. Sync service tests: 70 passed.
- Android phone testing confirmed platinum discovery, premium AI artwork, and sharing to Facebook.
- Signed Android App Bundle targets Google Play production as version 1.1.20, build 103.

## Submission

- Submitted to Google Play production on October 15, 2026, with review requested.
- Google Play accepted the signed bundle and validated the release before submission.
- Bundle SHA-256: `892f937d12a276e64430c6c218b480415f2c1640bee50c87e46a16f175097409`.
- Submission does not establish Google review approval or public availability.

## iOS preparation

The combined source also preserves the iOS startup white-screen repair, resilient optional-service startup, notification setup changes, and updated CocoaPods lockfile previously on main. These iOS changes still require a Mac build and iPhone verification. They do not change the Android bundle already submitted to Google Play.
