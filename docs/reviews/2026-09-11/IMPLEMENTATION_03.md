# Catalog search and pagination — SX-007

Date: 2026-09-11. Local implementation; deployment pending.

The catalog previously skipped new searches, platform changes, and sort changes while a request was loading. An old request could then populate results under newer controls. Pagination failures were silent and left an apparent loading indicator.

The screen now invalidates pending work immediately whenever the criteria change. Typing waits 300ms before fetching; clearing search, changing platform, and changing sort fetch immediately. Each request captures its criteria and offset. Only the current request generation may update rows, errors, loading state, or pagination. Obsolete requests can finish in the background but cannot publish results.

Every criteria change clears the old rows, resets the offset and end-of-results flag, and scrolls to the top. Pagination requests are serialized within the current generation. Successful pages advance by the returned row count; failures retain the existing rows and offset and offer an explicit retry. Initial failures show an error with Retry instead of an empty-results message. Timers are cancelled on disposal.

Catalog ordering now breaks equal-name ties by platform ID and platform game ID. This makes offset pagination deterministic for an unchanged catalog; concurrent catalog inserts/deletes can still shift pages. Cursor pagination is not part of this change.

## Validation

Five widget tests use a fake repository with manually completed requests. They cover typing during an initial fetch and during debounce, filter/sort changes during active requests, old successes and errors arriving after new results, stale pagination, retrying a failed page at the same offset, retrying an initial failure, and disposing with a pending request/timer. No production requests were made by these tests.

## Release verification

Deploy the application build, then verify search, clearing search, platform filters, both sort directions, pagination, and failed-page retry under network throttling. Check both list and grid presentations. No schema or Edge Function deployment is required for this batch. Keep SX-007 unchecked until the release is verified.

Local results: [five focused tests](catalog-focused-tests.txt) passed; [full Flutter suite](catalog-flutter-tests.txt) passed 61 tests with eight existing web-only tests skipped on the native runner; [analysis](catalog-analyze.txt) found no issues; [release web build](catalog-build.txt) passed with the existing optional Wasm dry-run warnings. No live throttled-browser or production deployment verification was performed in this batch.
