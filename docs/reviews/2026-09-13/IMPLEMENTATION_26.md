# Batch 26 — Desktop next-session discovery

Implemented locally on 2026-09-13. No deployment or database changes.

The desktop dashboard now places **Your next session** beneath the profile totals. It reuses the existing next-best-action selector, daily momentum card, and weekly recap card, backed by the existing account-aware engagement provider. Players can discover claimable rewards, daily challenges, a game to continue, and their weekly progress without finding those features through secondary menus.

Recommendations open their existing destinations. Game recommendations use canonical platform/game routes and offer platform selection for multi-platform games. Returning from a recommendation or the challenge hub refreshes engagement data. Permanent All challenges and Weekly recap links remain available when cards are dismissed. Next-action and recap dismissals last for the local day/week and are stored separately per account on this device; mobile's existing dismissal preferences remain unchanged.

The new section loads independently of platform totals and recent games. It does not manufacture zero progress during loading or errors; failed engagement reads expose Retry challenges. Existing library data is reused without another library request. Cards sit side by side at sufficiently wide section widths and stack below 900px. Dashboard refresh invalidates engagement data as well as the existing stats/library providers.

This desktop section suppresses the selector's optional premium-preview fallback without querying or granting premium status. Existing mobile behavior remains unchanged through a defaulted selector option. Recommendations otherwise retain the existing selection logic. No reward is claimed merely by opening a card, and no reminders or external messages are sent.

Validation:

- Four new widget tests pass: 700px/1240px layout and challenge navigation, loading/error retry without invented progress, persistent account-scoped dismissal, and recap navigation.
- `flutter analyze --no-pub`: no issues.
- Full Flutter suite: 123 passed, 9 existing platform-specific skips.
- `flutter build web --release --no-pub --no-tree-shake-icons`: passed. Existing optional Wasm compatibility warnings remain; the JavaScript build succeeds.

Remaining: deployed browser verification, actual recommendation-to-session/recap engagement measurement, and refinement of recommendation relevance. This is desktop visibility of existing features, not completion of the broader SX-033/034/037 experiment criteria. The dedicated full weekly recap continues to load on its existing destination; this dashboard uses summary fields from the engagement snapshot. Mobile presentation and reminders remain as previously implemented.
