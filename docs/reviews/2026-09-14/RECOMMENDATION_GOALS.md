# Recommendation goals — 2026-09-14

Implemented locally after the user approved account-default plus per-game controls.

Desktop's Your next session header and the mobile next-action card expose Recommendation goals. Choose a default of 100% including DLC or Platinum (PlayStation), then choose a library game and set an override or restore the default. Saving clears session skips so the revised candidate set is available immediately. Choices are stored separately per account in device/browser preferences and shared by both layouts; they do not sync between devices.

100% mode retains the completion/recent-progress ranking. Platinum mode applies to games with PlayStation versions, skips games where every PlayStation version has an earned platinum, and ranks remaining candidates using recent trophy activity with a neutral progress score. It does not use overall completion as platinum proximity. Xbox/Steam-only games continue to use completion mode. Reward and streak actions retain priority.

The available library model records earned platinum state but does not prove platinum availability or provide reliable required-group progress. Platinum cards and the settings dialog explicitly explain this limitation and direct players to inspect trophies. This is a goal-aware suggestion, not a verified platinum roadmap or obtainable-trophy guarantee. Mixed-platform titles still present their existing platform selector; the goal applies to their PlayStation versions.

Validation covers earned-platinum exclusion despite remaining DLC, per-game completion override, recent-activity ranking without DLC-percent claims, Steam behavior, save/reload and account isolation. Full Flutter suite: 145 passed, 9 existing platform-specific skips. Analysis passed with no issues. Release web build passed with existing optional Wasm compatibility warnings; the local preview responded HTTP 200. Settings saving has disabled controls while pending and retains choices for retry after failure.

No database migration, purchase/subscription change, push, or production deployment in this batch. Group-aware platinum proximity, cross-device preferences, and catalog-card totals remain future work. Game-detail catalog totals were implemented in USER_TEST_FIXES.md.

Follow-up: the Override a game selector now includes None, allowing the user to deselect a game and hide its editor. Selecting None preserves already configured overrides; choose Use account default for a game to remove its override. The save/reload widget test verifies deselection and preserved settings.

Follow-up: hidden recommendation cards now expose Show recommendations on both dashboard layouts. Restoring removes the saved dismissal and survives refresh; it preserves selected goals and skipped-game choices. The desktop navigation test now verifies hide, revisit, restore, and revisit again. Six focused dashboard tests pass.
