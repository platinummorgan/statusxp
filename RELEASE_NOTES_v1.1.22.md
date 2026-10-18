# StatusXP 1.1.22 (105)

## Google Play release notes

Keep using StatusXP while a gaming account needs reconnection. Your dashboard, saved games, achievements, and settings remain accessible. Reconnect only the affected platform when you want to sync it, and return to the dashboard at any time. Other connected platforms can still sync automatically. This update also fixes missing Xbox feed stories for confirmed achievements that have no unlock date.

## Changes

- Reconnect checks run in the background and no longer block authenticated app entry, including while checking or offline.
- Each PlayStation, Xbox, and Steam sync screen checks only its own platform, including screens opened directly from Settings. Reconnection and error screens provide a way back to the dashboard.
- Automatic syncing waits for the requirement check and skips affected platforms independently. Existing server authorization, credential rotation, and same-account checks remain enforced.
- Xbox feed verification includes confirmed undated unlocks from the same import window, deduplicates date promotion, and preserves unknown unlock dates. Historical/undated activity remains classified as an import.
- Live diagnosis confirmed two PS-only users at the reconnect gate, and two Xbox imports whose missing dated rows explained their missing feed stories. Read-only replay verified exact gains of 24,297 and 18,924 Gamerscore after including two and 298 undated unlocks respectively.

## Validation and rollout

- Targeted Flutter analysis and reconnect navigation tests passed. Automatic-sync tests cover independently skipping a pending platform and withholding sync when checks fail.
- Full Flutter suite: 254 passed, nine existing skips.
- Sync-service suite: 72 passed, including undated feed facts, timestamp filters, date promotion, failed reads, and unchanged resyncs.
- Existing production SQL reconnect regression passed in a rollback-only transaction; no credential requirement was cleared or bypassed.
- Restored and verified the two missing Xbox stories as imports, using their original persisted baselines and confirmed unlocks; existing-story matching prevents duplicate posts.
- Publication results will be recorded after verification. iOS requires a Mac build and App Store submission.
