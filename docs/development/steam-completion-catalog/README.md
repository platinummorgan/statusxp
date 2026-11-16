# Steam completion membership catalog

**Historical manual catalog:** Steam membership is now selected automatically from native sets, with all available achievements as the fallback. These JSON files preserve previous decisions; they no longer define current requirements. The old manual approval RPC is retired. See the [current native-set policy and release](../../reviews/2026-11-16/NATIVE_STEAM_COMPLETION_SETS_RELEASE.md).


The dashboard calls these **Steam Completions**; the earned game badge is **Base Game 100%**. Each reviewed AppID contributes at most one completion. The combined dashboard **Total Completions** adds PlayStation Platinums, Xbox Mythics, and verified Steam completions, counting platform accomplishments separately.

## Reviewed coverage

| AppID | Game | Required original achievements | Excluded add-on achievements |
| --- | --- | --- | --- |
| 400 | Portal | 14 | 1 |
| 620 | Portal 2 | 50 | 1 |
| 18500 | Defense Grid: The Awakening | 57 | 30 |
| 252330 | Slender: The Arrival | 20 | 1 |
| 252490 | Rust | 48 | 68 |
| 288160 | The Room | 5 | 0 |
| 292030 | The Witcher 3 | 52 | 26 |
| 293220 | H-Hour: World's Elite | 60 | 0 |
| 425580 | The Room Two | 7 | 0 |
| 456750 | The Room Three | 10 | 0 |
| 578080 | PUBG: BATTLEGROUNDS | 37 | 0 |
| 814380 | Sekiro™: Shadows Die Twice | 34 | 0 |
| 892970 | Valheim | 53 | 0 |
| 1063730 | New World: Aeternum | 133 | 0 |
| 1085660 | Destiny 2 | 13 | 10 |
| 1086940 | Baldur's Gate 3 | 53 | 1 |
| 1091500 | Cyberpunk 2077 | 44 | 13 |
| 1097750 | Ezaron Defense | 16 | 0 |
| 1174180 | Red Dead Redemption 2 | 51 | 0 |
| 1245620 | ELDEN RING | 42 | 0 |
| 1326470 | Sons Of The Forest | 32 | 0 |
| 1361320 | The Room 4: Old Sins | 9 | 0 |
| 1574900 | Salt 2 | 36 | 0 |
| 1599340 | Lost Ark | 156 | 0 |
| 1604030 | V Rising | 49 | 0 |
| 1794680 | Vampire Survivors | 140 | 103 |
| 1995330 | Monos: The Endless Tower | 25 | 0 |
| 2062430 | BALL x PIT | 63 | 19 |
| 2427430 | S.T.A.L.K.E.R.: Call of Prypiat - Enhanced Edition | 47 | 0 |
| 2782500 | 逆水寒 | 39 | 0 |
| 2968420 | PowerWash Simulator 2 | 40 | 20 |
| 3405340 | Megabonk | 102 | 37 |
| 3981100 | Leaf it Alone | 18 | 36 |
| 5037510 | Playrooms | 30 | 0 |

Each JSON file records stable Steam API names, exclusions, edition context and review evidence. Console references are optional: Playrooms is reviewed from its official Steam schema, developer launch/update history and support-DLC scope. Its 30 original achievements have no excluded add-on achievements in the reviewed snapshot. [Playrooms validation](../../reviews/2026-11-15/PLAYROOMS_COMPLETION_REVIEW.md). Every existing Steam definition in the Witcher 3 and Cyberpunk 2077 lists has exactly one unique reference match. Hidden Steam descriptions are sometimes unavailable; original content membership comes from the reference grouping, while actual achievement eligibility always comes from Steam's own unlock state. Cyberpunk's original Master Crafter achievement retains its identity across the Legendary/Tier 5 terminology change. [CDPR Update 2.0](https://www.cyberpunk.net/en/news/49060/update-2-0), [Witcher expansion announcement](https://www.thewitcher.com/us/en/news/991/hearts-of-stone-blood-and-wine-two-massive-expansions-for-the-witcher-3-wild-hunt).

The November 15 personal-library batch reviewed all 34 pending games: 31 sets are approved and three have documented unresolved cases. Portal 2 is now reviewed with 50 originals and Talent Show excluded as a later Summer Sale addition. [Batch review and exceptions](../../reviews/2026-11-15/STEAM_PENDING_GAMES_REVIEW.md). The machine-readable [pending reviews](pending-reviews.json) are investigation records and cannot be submitted to the approval CLI.

For Early Access games, “day one” means the full 1.0 release, including existing Early Access achievements. If no achievements existed at full release, use the first official achievement set instead; exclude additions after that set. This user-confirmed exception currently covers PUBG (37 achievements introduced March 9, 2018) and Monos (25 introduced December 22, 2023), recorded explicitly in each review’s membership policy. Other games are not approved simply because all current achievements are in Steam group zero. Valve defaults unassigned achievements into the base set, which can leave older additions mixed in. [Valve achievement-set documentation](https://partner.steamgames.com/doc/features/achievements/ach_guide).

## Automated collection and review queue

Normal Steam sync automatically queues a new unreviewed game globally. The Railway worker collects its current Steam groups and stable IDs, recent and launch-window developer announcements, release details, and exact-title PlayStation or verified Xbox BaseGame references. It maps names and unique equivalent descriptions, checks complete reciprocal base coverage, retains Steam-only differences, and saves a structured proposal. Every catalog read is paginated beyond 1,000 rows. Steam group zero is evidence, never automatic proof of original membership.

Verified console completion lists can define a reviewed Steam base set. Require the equivalent regular base trophies and exclude the console Platinum itself, Steam-only extras and DLC from eligibility and estimated rarity. Slender is reviewed this way with 20 requirements and one excluded Steam-only achievement. Games without a verified console counterpart use the reviewed original Steam set, with the full 1.0 and first-official-set rules described above.

The worker processes up to three jobs per minute, leases work for ten minutes, retries evidence failures after thirty minutes, and revisits unresolved proposals after seven days. Schema ID changes queue an immediate new analysis and invalidate old leases. Schema snapshots retain first-seen evidence for future reviews; first-seen dates are not treated as historical launch dates. No player credentials or unlock data are collected by this worker.

Automatic approval is limited to a different AppID with the same exact game title and a unique, identical full achievement-name/description set already reviewed on Steam. The native fetched definitions must also match the stored snapshot. Required/excluded membership is copied from that reviewed source; hand-flagged exceptions and existing verified sets are preserved. This rule does not authorize automatic approval from a console name match or a Steam group label.

For other cases, export the generated record from sync-service:

```powershell
node export-steam-completion-review.js APPID ../review-APPID.json
```

A complete ID alignment exports a review candidate even when descriptions need manual comparison; unresolved issues remain in its evidence. Incomplete alignments export the full investigation report. Review original-release timing, the first-official-set exception where applicable, all Steam-only IDs, and any flagged requirement differences. Approve a candidate with explicit supporting evidence:

```powershell
node review-steam-completion-set.js ../review-APPID.json --scope-note "Original set and flagged differences confirmed from the launch announcement" --scope-evidence https://publisher.example/launch
# Add --apply after inspecting the dry-run output.
```

The queue and snapshots are service-only. A stale worker cannot publish after a schema or lease change. Membership approval never fabricates player progress: ordinary Steam sync still checks eligibility and dates. See the [automation release record](../../reviews/2026-11-15/STEAM_REVIEW_AUTOMATION.md).
