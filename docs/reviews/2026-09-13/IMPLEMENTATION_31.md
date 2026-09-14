# Batch 31 — Paged Flex Room picker results

Implemented locally on 2026-09-13. No migration or deployment.

The picker now requests 30 achievements per page and 30 games per platform variant. PlayStation can return up to 120 games across four variants, Xbox up to 90 across three, and Steam up to 30. Next/Previous controls replace an unpaged result list. Search is sent to the RPC before the response range is applied; changing search or selection steps returns to page one. Failed pages retry the same page, and an empty final page still allows Previous.

Paged requests explicitly order names ascending with game/achievement identifiers as tie-breakers. The picker therefore uses alphabetical achievement order; callers omitting the optional page argument retain the existing repository behavior and native RPC order. Game variant pages are merged and sorted within each displayed page, not globally across all variants. A full page enables Next without a count query, so exact multiples may lead to one empty final page.

The existing RPCs accept PostgREST response range/order parameters; their signatures are unchanged. This bounds response rows for picker requests, not the internal SQL work of those functions. Database execution plans and behavior under concurrent library changes still need live verification. Offset pagination can shift if a sync changes the library between pages.

Validation: widget coverage passes paging, failed-page retry, empty-final-page recovery, and search reset. HTTP-level mock checks verify range offsets/limits, explicit ascending order and identifier tie-breakers, composite game identity, and preserved search parameters. These checks caught and corrected the library's descending-order default. Full Flutter suite: 136 passed, 9 existing platform-specific skips. Analysis passed with no issues. Release web build passed with existing optional Wasm compatibility warnings.

Remaining: controlled browser verification with a large synced library, live RPC range behavior and query cost, optional showcase auto-fill isolation, and same-account timing measurements. This does not change live database permissions or deploy the picker.
