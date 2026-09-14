# Batch 30 — Flex Room picker search and retries

Implemented locally on 2026-09-13. No deployment or database changes.

The achievement picker now waits 300 ms after typing before searching. It retains the current game and achievement request rather than creating new futures on every rebuild. Request identity includes user, platform, game identifiers, and search text. Only one current future per result type is retained; search history is not accumulated in a cache.

Changing search immediately hides the previous results while the new query is pending. Late responses from removed future builders cannot become selectable under a newer query. Moving from game selection into achievements, or using breadcrumb back navigation, clears both the search text and pending debounce. Closing the picker cancels its timer.

Game/achievement RPC errors now propagate to the picker, which displays a retry action and readable failure copy instead of an empty-library message or raw error details. Retry replaces the failed future. The suggestions description now says “Suggested achievements for this category”; it no longer makes an unsupported AI-curation claim.

Validation: three new widget tests cover debounce/request counts and clean game-to-achievement search, failure/retry, and out-of-order results during a newer search. Analysis passed with no issues. Full Flutter suite: 134 passed, 9 existing platform-specific skips. Release web build passed with existing optional Wasm compatibility warnings.

Remaining: review server-side result limits/pagination and search correctness on large libraries, optional showcase auto-fill isolation, and deployed browser timing/interaction checks. This batch improves client request behavior; it does not claim all picker queries are bounded or establish a production speedup.
