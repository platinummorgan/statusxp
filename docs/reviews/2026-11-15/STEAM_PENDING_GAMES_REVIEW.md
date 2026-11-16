# Steam original achievement review

Reviewed November 15, 2026. This batch covers all 34 games that were pending in the connected account. **31 sets are verified; three remain under review with specific evidence or eligibility questions.** Each verified set is shared globally by AppID. Normal Steam sync evaluates current native unlocks; reviews do not manually grant player completions.

## Rules

The Early Access cutoff is the full 1.0 release, as confirmed by the user. If no achievements existed at full release, the first official achievement set becomes the base set, with subsequent additions excluded. Include original Steam-exclusive achievements. Exclude DLC and later updates, even when all current achievements sit in one Steam group. Expansion content that predates a Steam port remains expansion content when its requirements belong to a separate expansion set. Use the same required IDs for completion eligibility and the minimum rarity estimate.

## Classification

| AppID | Game | State | Required | Excluded |
| --- | --- | --- | --- | --- |
| 400 | Portal | Verified | 14 | 1 |
| 620 | Portal 2 | Verified | 50 | 1 |
| 330840 | Game of Thrones - A Telltale Games Series | Needs review | — | — |
| 2782500 | 逆水寒 | Verified | 39 | 0 |
| 18500 | Defense Grid: The Awakening | Verified | 57 | 30 |
| 252330 | Slender: The Arrival | Verified | 20 | 1 |
| 252490 | Rust | Verified | 48 | 68 |
| 288160 | The Room | Verified | 5 | 0 |
| 1063730 | New World: Aeternum | Verified | 133 | 0 |
| 1085660 | Destiny 2 | Verified | 13 | 10 |
| 293220 | H-Hour: World's Elite | Verified | 60 | 0 |
| 425580 | The Room Two | Verified | 7 | 0 |
| 456750 | The Room Three | Verified | 10 | 0 |
| 578080 | PUBG: BATTLEGROUNDS | Verified | 37 | 0 |
| 700580 | Rust - Staging Branch | Needs review | — | — |
| 814380 | Sekiro™: Shadows Die Twice | Verified | 34 | 0 |
| 1086940 | Baldur's Gate 3 | Verified | 53 | 1 |
| 1097750 | Ezaron Defense | Verified | 16 | 0 |
| 1245620 | ELDEN RING | Verified | 42 | 0 |
| 1326470 | Sons Of The Forest | Verified | 32 | 0 |
| 1604030 | V Rising | Verified | 49 | 0 |
| 892970 | Valheim | Verified | 53 | 0 |
| 1794680 | Vampire Survivors | Verified | 140 | 103 |
| 1995330 | Monos: The Endless Tower | Verified | 25 | 0 |
| 1170970 | Marbles on Stream | Needs review | — | — |
| 1174180 | Red Dead Redemption 2 | Verified | 51 | 0 |
| 1361320 | The Room 4: Old Sins | Verified | 9 | 0 |
| 1574900 | Salt 2 | Verified | 36 | 0 |
| 1599340 | Lost Ark | Verified | 156 | 0 |
| 2062430 | BALL x PIT | Verified | 63 | 19 |
| 2427430 | S.T.A.L.K.E.R.: Call of Prypiat - Enhanced Edition | Verified | 47 | 0 |
| 2968420 | PowerWash Simulator 2 | Verified | 40 | 20 |
| 3405340 | Megabonk | Verified | 102 | 37 |
| 3981100 | Leaf it Alone | Verified | 18 | 36 |

Verified JSON records in the [catalog](../../development/steam-completion-catalog/README.md) contain exhaustive stable IDs, source identities, release context and reference mappings where available. The batch classifies 1439 required IDs and 326 excluded IDs. These are manual content/history reviews; Steam group membership alone is not a launch snapshot.

## Remaining cases

### Game of Thrones - A Telltale Games Series

Original season spans six episodes released on different dates. The current 48-ID set has eight achievements per episode, but original schema timing must be established before deciding whether all six episodes satisfy the launch-day rule.

Next: Obtain the launch schema or settle the original-season cutoff explicitly.

Evidence: [Source 1](https://store.steampowered.com/app/330840/), [Source 2](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/519372501701083965).


### Rust - Staging Branch

Separate Rust staging/test AppID with six achievements and no ordinary full-release store listing; production Rust has its own reviewed set.

Next: Settle eligibility for test branches before treating this as another completed game.

Evidence: [Source 1](https://steamcommunity.com/achievements/700580/?l=english).


### Marbles on Stream

Steam release November 6, 2019; November 9 patch notes already add new Steam achievements. Current 58 IDs cannot all be assumed to be original.

Next: Recover the first native achievement schema and separate subsequent seasonal additions.

Evidence: [Source 1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/2448197582025670887).

## Validation

All verified records exactly cover the current stored catalog and independently fetched native Steam schema, with no duplicate or overlapping classifications. Each production review was rehearsed inside a rolled-back transaction, then applied atomically with membership count assertions. Current player qualification is checked by a normal phone-triggered Steam sync. SQL releases are archived under supabase/migrations/_manual_production_archive; no schema push was used.

The first 25-set sync passed, changing Steam completions from 1 to 2 and pending reviews from 34 to 9. The Room qualified at 5/5 and received 2.99 completion XP at 64.9% estimated rarity. Subsequent reviews for Rust, Lost Ark and Megabonk are applied and independently read back. The next normal sync was denied by the existing 15-minute Premium cooldown (HTTP 429); no quota or sync-session bypass was used. Until that next sync, the dashboard has 2 Steam completions, 9 pending reviews and 78,648 StatusXP. The catalog has six actual unresolved sets; three additional displayed pending entries need their new revision evaluated.

Rust has 48/48 required IDs in the last native snapshot and is expected to become the third completion on the next allowed sync. This remains an expectation until current native unlocks are checked again. Expected pending count after that sync is six. [Sanitized verification](steam-pending-games-verification.json).

## First official achievement set exception

The user approved this rule on November 15, 2026. PUBG’s first official set is 37 achievements introduced with PC 1.0 Update #7 on March 9, 2018. Monos’s first official set is 25 introduced on December 22, 2023. Fresh native Steam schemas exactly match the stored 37/25 definitions. Both reviews passed rolled-back SQL rehearsals and were applied atomically with count/policy assertions. No user completion is manually granted; the next allowed sync checks native progress.

Four cases remain: Slender, Game of Thrones, Marbles on Stream, and Rust Staging Branch.

## Slender console-equivalent review on November 16

The user confirmed that matching the PS5 Platinum requirements qualifies Steam base completion and excludes the Steam-only I Escaped? achievement. PS5 has 20 regular trophies plus the Platinum. All 20 regular requirements map to Steam IDs, including four renamed trophies and the Tangled spelling difference. The verified Steam set has 20 required IDs and one exclusion. Native synced PS5 data confirms the personal earned Platinum at 21/21; the library API returns that PS5 game correctly.

The supplied PSNProfiles guide returned HTTP 403 to automated access, so the actual comparison used the stored native PS5 definitions. The guide URL is retained as the user-supplied reference. This is explicitly a console_equivalent_base_game review rather than an inferred Steam launch list.

The SQL rehearsal and live readback passed. Estimated rarity is 3.0% across the 20 required IDs, yielding 52.98 completion XP when earned. The personal Steam snapshot has 8/20 requirements. The next normal Steam sync will evaluate the membership revision. Three unresolved games remain.
