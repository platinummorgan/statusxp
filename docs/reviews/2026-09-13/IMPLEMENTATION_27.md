# Batch 27 — Recommendations that reflect recent progress

Implemented locally on 2026-09-13. No deployment or database changes.

The shared next-action selector now balances completion percentage with recent earned-achievement activity. Both mobile and the desktop section from batch 26 use the change. A game at 70% with an unlock in the last seven days can now appear ahead of a dormant game at 95%. Claimable rewards and streak actions retain their existing priority.

The card says **Continue [game]** and explains the recommendation using the actual completion percentage and recent achievement window, or a closest-unfinished-game explanation when recent activity is absent. It does not promise an easy finish or infer remaining effort, DLC requirements, missability, or achievement obtainability.

Ranking uses completion plus 30 points for an earned achievement less than seven days ago, or 15 points for one less than thirty days ago. These are initial product heuristics, not measured predictions. Eligibility remains 20% to below 100%. Missing activity falls back to completion; future achievement dates and non-finite completion values are excluded from their respective signals. Last-played timestamps are not used because that field may represent a sync. Equal scores use title ordering to avoid changes caused only by input order. No new network requests are added.

Validation includes recent-progress ranking, seven/thirty-day boundaries, missing/future timestamps, sync-only data, invalid completion, stable title ties, and existing reward/streak priority. Full Flutter suite: 127 passed, 9 existing platform-specific skips. Analysis passed with no issues after a brace-style fix. Release web build passed (`flutter build web --release --no-pub --no-tree-shake-icons`); existing optional Wasm compatibility warnings remain.

SX-034 remains in progress. Remaining work includes deployed verification, recommendation-use/subsequent-progress measurement, and user controls for choosing a different suggestion. Effort, obtainability, and DLC-aware ranking require supported data and remain open. Recommendations use synced data and cannot establish current in-game activity.
