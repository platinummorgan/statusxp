# Batch 29 — Load recent Flex Room highlights on demand

Implemented locally on 2026-09-13. No deployment or database changes.

The Flex Room showcase no longer requests or waits for recent notable achievements. Opening **Recent Flexes** starts an independent, user-keyed request. The tab has its own loading indicator and Retry highlights action. A failed read is shown as an error, not an empty activity history. Returning to Showcase keeps the loaded showcase and editing state available.

The repository retains its default combined-data behavior for other callers through an optional `includeRecent` argument. The screen's showcase provider explicitly disables recent loading for both existing and new rooms. The independent recent provider is automatically disposed when unused; reopening the tab can fetch fresh highlights. Successful empty results still show the existing empty-state copy.

Automatic population from earned achievements remains enabled. Optional superlative auto-fill is still part of showcase loading and is a separate remaining optimization. This batch removes one RPC from initial screen loading; it does not establish a measured production latency improvement or complete the full Flex Room performance milestone.

Validation: new widget test verifies zero highlight reads on Showcase, lazy loading on tab selection, honest error/retry, successful empty response, and return to showcase tiles. Existing new/saved-empty-room repository tests now verify auto-population without a recent-highlights RPC. Full Flutter suite: 131 passed, 9 existing platform-specific skips. Analysis passed with no issues. Release web build passed; existing optional Wasm compatibility warnings remain.

Remaining: isolate optional auto-fill while protecting saved selections and edit races, picker correctness/performance review, and deployed same-account measurements. No live account data was changed.
