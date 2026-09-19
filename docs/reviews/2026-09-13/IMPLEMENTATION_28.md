# Batch 28 — Choose another recommendation

Implemented locally on 2026-09-13. No database changes or deployment.

Desktop and mobile next-action cards now offer **Suggest another game** when recommending a game. Choosing it excludes that game from the current session's suggestions. **Reset suggestions** restores the original candidate set. When all eligible suggestions have been seen, the card offers browsing or reset instead of repeating a skipped game or turning the choice into a premium prompt. Rewards and streak actions retain priority.

Choices are held in memory, separately per account, and shared between dashboard layouts. They survive navigation while the app remains running but reset on a fresh app session. The UI states this explicitly. Game identities use sorted platform/game identities; legacy entries without platforms fall back to their title. Exclusions do not change the user's library, achievements, or saved goals, and add no network requests.

Validation: phone-width choose-another/exhaustion/reset journey, isolated account state, and reward/streak priority with skipped candidates pass. Existing desktop layout, navigation, and dismissal coverage remains included. An initial constant-expression error in the test fixture was corrected before final validation. Full Flutter suite: 130 passed, 9 existing platform-specific skips. Release JavaScript web build passed with existing optional Wasm compatibility warnings. Analysis passed with no issues after correcting a const-literal lint in the test.

SX-034 remains in progress. Deployed browser checks and recommendation-to-progress measurement remain open, along with richer supported ranking signals. These controls express a session choice; they do not train a persistent preference model or hide games permanently.
