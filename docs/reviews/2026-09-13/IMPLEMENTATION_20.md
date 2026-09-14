# Batch 20 — Flex Room loading and automatic highlights

Implemented locally on 2026-09-13. Not deployed.

New rooms and existing empty configurations now receive suggested highlights and superlative tiles from the user's earned achievements. Users without earned achievements get a direct connection/sync action. Automatic writes only run for the room owner and preserve stored composite selections, including selections whose metadata could not be fetched during that load.

Configured tiles and picker hydration share a bounded loader that deduplicates simultaneous requests and uses complete platform/game/achievement identities. Each group of up to 20 tiles uses an ownership query followed by parallel achievement/game queries. Results are not cached across later loads or users. Superlative suggestions are hydrated together instead of individually.

The screen loads profile/title once per viewed account and ignores stale responses. Failed saves retain the edit draft and show failure. Desktop showcase cards use four columns, with three on medium widths and two on phones. The header is smaller, the date explicitly describes showcase editing, and the stats strip fits a 390-pixel viewport.

Validation:

- 11 new focused tests pass: batched request count, duplicate identities, user isolation, missing ownership, retry, escaped filter values, automatic population of new/saved-empty rooms, preservation of stored keys, no fabricated achievements, mobile/desktop layout, profile request count, sync prompt, and failed-save behavior.
- Full Flutter suite: 88 passed, 9 existing platform-specific skips.
- `flutter analyze --no-pub`: no issues.
- `flutter build web --release --no-pub --no-tree-shake-icons`: passed. The optional Wasm compatibility scan reports existing `dart:html`/`dart:js_util` dependencies; the standard JavaScript web build succeeded.

Performance evidence: the signed-in production baseline made 48 tile hydration requests for 16 tiles (55 total REST requests). The new loader test makes three tile hydration requests for 16 tiles plus duplicates. This is a verified request-count reduction, not a measured production latency improvement. Repeat the same-account trace after deployment.

Remaining Flex Room work: render recent highlights/optional suggestions independently from initial showcase loading; complete picker search/filter verification; validate live saves and repeat browser measurements. Existing category suggestion RPCs remain separate, so initial automatic population still makes category queries. Co-op hub implementation follows this batch; its checklist remains in the feature/page review.
