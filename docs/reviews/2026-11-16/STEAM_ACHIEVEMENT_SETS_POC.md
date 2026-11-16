# Steam Achievement Sets: read-only proof of concept

Checked November 16, 2026. **No production writes, syncs, worker jobs, migrations, deployments, scoring changes, or dashboard changes were performed.** The research files are standalone and are not imported by the running service. Existing unrelated workspace changes were preserved.

## Finding and recommendation

Set membership is usable: the anonymous public page supplied structured achievement definitions whose `api_name` values matched the documented Steam API in **49/49 sampled catalog games, covering 6,140 achievement IDs**. We found no documented set-membership read endpoint in the Steamworks Web API documentation or the supported-method catalog returned with our existing key. The working route is embedded JSON on the official public achievement page, with no external API stability contract.

Recommend an automated, shared per-AppID catalog adapter, first running in observation mode. Use a validated official base set when the full base scope is unambiguous; otherwise use **All achievements**. The proof uses the same selected IDs for qualification and minimum-rarity estimation, at **1×**, and counts a game once. No PlayStation/Xbox comparison is needed.

This will automate processing without manually mapping every game. It will **not** automatically discover a DLC-free original set for every game: most sampled developers have not supplied usable separation. Our strict acceptance policy selected official base sets for **2/49** games; **47/49** used the fallback. This is a deliberately conservative interpretation of “full base game,” not a rule imposed by Valve. In particular, a populated built-in base set plus additional unrestricted sets is treated as ambiguous. The literal built-in set sizes are preserved in the results so this choice is reviewable.

## Existing StatusXP implementation

| Area | Existing location and behavior |
| --- | --- |
| Native definitions | `sync-service/steam-sync.js:479`: `GetSchemaForGame/v2`, English definitions. |
| Player unlocks | `sync-service/steam-sync.js:501`: `GetPlayerAchievements/v1`, keyed by `apiname`. |
| Rarity | `sync-service/steam-sync.js:735`: `GetGlobalAchievementPercentagesForApp/v2`, keyed by achievement `name`. |
| Stored ID | `sync-service/steam-sync.js:864`: `achievements.platform_achievement_id = achievement.name`. AppIDs are stored as text; Steam uses platform ID 4. |
| Completion recording | `sync-service/steam-completions.js` calls `record_steam_completion` from normal Steam sync, including the unchanged-achievements path. It does not hardcode individual games. |
| Required membership | `steam_completion_catalog`: observed/required/excluded IDs, review state, evidence, membership revision, minimum rarity and generated points. `steam_completion_progress` holds per-user native qualification/counts and dates. |
| Qualification and points | `_manual_production_archive/20261115213000_steam_completions.sql`: completion requires every reviewed required ID; rarity is the minimum over those same IDs. Missing states are rejected. Live generated points currently use `0.5 + 57.5 × (1 − rarity/100)^3`, i.e. **5× rarity component**. |
| Existing review worker | `sync-service/steam-completion-review.js:14` already parses the public `schema_v2` payload for evidence. Its console/day-one proposal rules differ from this investigation. The POC reuses only its parser. |

The proposed fallback would change the existing pending/manual-review behavior. It is not already enabled. This POC's **1× weight is local only**; the live 5× formula remains untouched.

## What Valve documents

Valve currently labels Achievement Sets beta. Each game has one built-in base set; unassigned achievements default into it and an empty base set is hidden. Other sets may represent modes, characters, chapters, events, or DLC. DLC sets can carry an ownership restriction; developer-only sets are hidden. Archived achievements no longer block completion, while spoiler achievements still do. Completed sets retain completion when later achievements are added. Any completed set can qualify a game for Steam's Completionist Showcase, so that showcase is not proof of completing the full base game. [Valve achievement guide](https://partner.steamgames.com/doc/features/achievements/ach_guide).

The documented schema, player-unlock and global-percentage endpoints remain useful for IDs, native earned state, and rarity. No membership method was found in this interface or the accessible supported-method listing. This does not establish that Valve has no private/internal endpoint. [ISteamUserStats Web API](https://partner.steamgames.com/doc/webapi/ISteamUserStats).

## Public payload and stability

Requests to `https://steamcommunity.com/achievements/APPID/?l=english` succeeded anonymously for all sampled games. The page contains `<script id="valve-ssr-data">`; its JSON includes `renderContext.queryData`, itself serialized JSON. A query keyed by `['achievements', APPID, 'schema_v2']` supplies:

```text
schema: appid, language, schema_hash, schema_version, groups[]
group: id, name, dlcappid, archived, ispublic, developeronly, order, achievements[]
achievement: api_name, internal_key, groupid, archived, hidden, localized text/icons
```

Join `api_name` to Web API definition `name`, player `apiname`, global-rarity `name`, and our stored `platform_achievement_id`. Do not use display text, array position, or `internal_key` as the canonical identifier. Observed built-in base group ID is `0`; `dlcappid > 0` identifies a restriction to a particular DLC. `dlcappid == 0` alone does not prove original base content.

PowerWash Simulator 2, Vampire Survivors, Portal 2, Team Fortress 2, and Pillars of Eternity were fetched twice more in English and once in French. All **15 repeat requests** matched the original membership/group/archival signatures. Localization did not change IDs. This is short-run repeatability, not a guarantee against future markup/schema changes, rate limits, outages, access restrictions, or developer edits. Hash/version changes should trigger revalidation; names should never drive classification.

## Representative live tests

All rows below joined public IDs to documented API IDs exhaustively. All except the marked archive control are in currently linked StatusXP Steam libraries. These are observed configurations, not inferred launch histories.

| Game / AppID | Observed configuration | Proposed required IDs |
| --- | --- | --- |
| [PowerWash Simulator 2 / 2968420](https://steamcommunity.com/achievements/2968420/?l=english) | 60 total: base 40; Adventure Time 10 restricted to DLC 4173830; STAR WARS 10 restricted to DLC 4229450. | **Base game complete: 40** |
| [BALL x PIT / 2062430](https://steamcommunity.com/achievements/2062430/?l=english) | 82 total: base 63; Risen Ballbylon 19 restricted to a DLC. | **Base game complete: 63** |
| [Vampire Survivors / 1794680](https://steamcommunity.com/achievements/1794680/?l=english) | Base 140, unrestricted Extra Content 63, Moonspell 18 and Foscari 22 with DLC restrictions. Literal base is identifiable, but custom free-content scope is not typed. | **All achievements: 243**, conservative policy |
| [Portal 2 / 620](https://steamcommunity.com/achievements/620/?l=english) | Single-player 29 and co-op 22 are unrestricted custom sets; no populated built-in base set. | **All achievements: 51**, one game completion |
| [Leaf it Alone / 3981100](https://steamcommunity.com/achievements/3981100/?l=english) | Hometown, Castle and Sakura each have 18, all unrestricted; no populated built-in base. | **All achievements: 54**, no inference from names |
| [Euro Truck Simulator 2 / 227300](https://steamcommunity.com/achievements/227300/?l=english) | 16 groups, including base 29, DLC-restricted groups, unrestricted Driving Academy 10 and Multi-Expansion 3. Restrictions alone cannot express the whole content distinction. | **All achievements: 114** |
| [Team Fortress 2 / 440](https://steamcommunity.com/achievements/440/?l=english) | 520 definitions across 16 mostly class/mode/event sets; literal base 47. Four YouTube replay achievements explicitly archived. | **All available achievements: 516** |
| [The Witcher 3 / 292030](https://steamcommunity.com/achievements/292030/?l=english) | All 78 in one default group, including expansion content; default membership is not useful separation. | **All achievements: 78** |
| [Rust / 252490](https://steamcommunity.com/achievements/252490/?l=english) | All 116 in one default group; no typed original/day-one subset. | **All achievements: 116** |
| [Slender: The Arrival / 252330](https://steamcommunity.com/achievements/252330/?l=english) | All 21 in one default group. The Steam-exclusive `ESCAPED_ACHIEVEMENT_1` remains required. | **All achievements: 21** |
| [Playrooms / 5037510](https://steamcommunity.com/achievements/5037510/?l=english) | One default group, 30; no console reference required. | **All achievements: 30** |
| [The Room / 288160](https://steamcommunity.com/achievements/288160/?l=english) | One default group, 5. | **All achievements: 5** |
| [Pillars of Eternity / 291650](https://steamcommunity.com/achievements/291650/?l=english) — supplementary archive control, outside tracked sample | API/page 48; base 36 includes archived `pe-backer`; two White March DLC sets contain the other 12. | **Base game complete: 35 available** |

Archived definitions were present in the anonymous structured payload for the two archive examples even though the rendered UI can hide locked archived entries. Team Fortress 2 marks the four individual replay achievements; Pillars marks the retired Kickstarter achievement. Archived-group and developer-only handling were tested with fixtures, not a live developer-only/private title.

## Scope and edge cases

- **Steam-exclusive achievements:** include them whenever they belong to the selected native required set. Console absence is never DLC evidence. Slender's proposed 21 replaces the earlier console-equivalent 20 only in this simulation.
- **Free updates:** the payload has no universal “day one” or “free update” classification. New IDs may enter the built-in set or a custom unrestricted set. The POC falls back when additional unrestricted sets make full-base scope ambiguous. Accepting the literal built-in set for such games would be a separate product-policy choice; Vampire's 140 is exposed, not silently substituted.
- **Multiple base-looking sets:** there is one special built-in base set, but multiple unrestricted custom sets can contain original game modes. Portal 2 proves that selecting only the first visible set or treating every set as a game completion would be wrong.
- **Ungrouped/default:** all default-group achievements remain requirements under the fallback. A lone group 0 does not prove separation from DLC. No cross-platform guesses are made.
- **Archived/hidden:** remove explicitly archived or unavailable requirements only when the schema metadata validates and joins completely. Spoiler/hidden achievement details do not remove a requirement. Archive/availability metadata that cannot be trusted must not silently shrink the fallback.
- **Missing grouping or failed parser:** use all standard API definitions; when archive metadata is unavailable, archival exclusions cannot be established. Incomplete native schema/player responses leave completion unknown rather than grant it. A stored/API mismatch needs a normal definitions refresh before production evaluation.
- **Historical completion:** the POC recomputes current requirements. It does not recover Steam's retained set-completion history. We did not find a documented native historical completion flag in the endpoints tested. StatusXP must choose and version its treatment of previously awarded completions and later requirement changes before rollout. Current unlock dates alone cannot reconstruct all historical sets.

## Completion and estimated rarity

Let `R` be the selected, nonempty set of available required native IDs. Qualification is `every R member has achieved == 1`; each AppID contributes either **0 or 1** to the dashboard, regardless of its number of sets.

```text
estimated unlock percentage = min(global unlock percentage for every ID in R)
completion XP at requested 1× = round(0.5 + 11.5 × (1 − estimated percentage / 100)^3, 2)
```

The percentage is an **estimate**, not the measured population intersection of all requirements. A valid 0% is preserved and gives 12 XP; missing/invalid rarity leaves the estimate and XP unknown. No incomplete game receives completion XP. Example: PowerWash Simulator 2's required 40 have a minimum of 12.2%, giving a potential 8.28 XP; its DLC rarities do not enter that estimate.

Read-only native unlock checks were performed for 17 sampled games in the research account's library. Playrooms qualifies at 30/30 and The Room at 5/5. **Rust is 55/116 under the fallback, so it would cease qualifying despite its existing reviewed 48/48 day-one completion.** These checks cover the sample, not a full hypothetical account leaderboard recalculation. No account totals were overwritten.

## Measured catalog coverage

The inventory has **26 currently linked, unmerged Steam accounts**, **1,400 distinct tracked AppIDs**, **1,016 AppIDs with earned achievements**, and **2,126 user-game rows**. This is linked-library coverage; useful recent-play coverage could not be established from stored `last_played_at` values.

The sample combines the 40 most widely tracked titles with earned achievements and a targeted set of grouping/completion cases, deduplicated to 49. It covers **49/1,400 titles (3.5%)** and **248/2,126 user-game rows (11.7%)**. It is not random, so do not extrapolate its adoption rate to all libraries.

| Sample result | Count |
| --- | ---: |
| Public page/API achievement IDs join exactly | 49/49 |
| Stored catalog also matches current API exhaustively | 48/49 |
| Official base accepted under strict full-base policy | 2/49 (4.1%) |
| Single default group: all-achievements fallback | 42/49 |
| Unrestricted custom sets make full-base scope ambiguous | 3/49 |
| No populated built-in base set | 2/49 |
| All titles evaluable without manual membership mapping, using fallback | 49/49 |

Euro Truck Simulator 2 has **106 stored IDs versus 114 current API/page IDs**. Every stored ID still matches; eight current IDs are not yet stored. This is catalog freshness, not an incompatible join key. Do not claim full stored membership coverage until normal sync imports them. Pillars is a supplementary control and excluded from all sample/catalog denominators. Full-catalog official-group adoption remains unmeasured.

## Proposed implementation after this proof

1. Add a shared, cached per-AppID membership adapter alongside normal schema ingestion. Keep raw public evidence, source URL, fetched time, hash/version, selected policy and exact required IDs. Validate page AppID, exhaustive API joins, uniqueness, metadata types and group membership. Refresh with bounded concurrency, backoff and a configurable TTL; a page request should not be required for every player sync.
2. Resolve one requirement policy: `official_base_game` when unambiguous, otherwise `all_achievements`. Preserve the fallback reason and archive limitations. Never use console matching to exclude Steam IDs. Handle API/player fetch failures as unknown. Keep transient provider failures distinguishable from genuine absence of grouping; do not flip a previously verified policy simply because a request failed.
3. Reuse native player unlocks and global rarities against that same revision of required IDs. Persist qualification and estimate together, enforce one award per `(user, AppID)`, and expose the truthful label: “Base game complete” or “All achievements.” Keep rarity explicitly marked “Estimated.”
4. Run a read-only shadow comparison across the linked catalog before any production transition. Report gains/losses against existing manually reviewed sets, changed estimates, unavailable data, and dashboard/count differences. Settle historical completion retention and the replacement of existing manual policies before changing awards. Apply the requested 1× only in the eventual explicitly scoped scoring release.

The proof supports building this adapter. It does not support silently replacing current requirements, deploying dashboard logic now, or claiming Valve grouping supplies a launch-day/DLC-free set for every title.

## Reproduction and artifacts

- `sync-service/research/steam-achievement-sets-poc.js`: standalone read-only catalog/API/page collector and pure selector/evaluator.
- `sync-service/research/steam-achievement-sets-poc.test.js`: **11 passing tests** for DLC membership, Steam-exclusive IDs, fallback, ambiguous/free sets, one-count semantics, same-set rarity at 1×, archive/spoiler behavior, empty requirements, incomplete responses and malformed metadata.
- `sync-service/research/check-steam-set-stability.js`: five-game repeat/locale check, public pages only.
- [Sanitized results and all tested AppIDs](steam-achievement-sets-results.json): public grouping summaries, counts, IDs joined, selection reasons, repeatability checks and control result. No credentials or provider-account identifiers.
- Raw public payloads and local account-only preview are retained in ignored `.railway-upload/steam-sets-poc-20261116/`; they are not production inputs.

From the repository root, run the tests with `node --test sync-service/research/steam-achievement-sets-poc.test.js`. The collector uses existing local service configuration for SELECT queries and an existing Steam key; optional `--account-name`, `--app-ids` and `--output` restrict the research. It invokes no mutation RPCs. The public repeatability check expects the pilot snapshots at its documented ignored directory.

## All sampled catalog titles

The following table is generated from the captured results; counts reflect the November 16 snapshot. “All” excludes explicitly archived/unavailable requirements when validated metadata establishes them.

| AppID | Game | API IDs | Required | Policy | ID join |
| --- | --- | ---: | ---: | --- | --- |
| 220 | Half-Life 2 | 69 | 69 | All | Exact |
| 400 | Portal | 15 | 15 | All | Exact |
| 440 | Team Fortress 2 | 520 | 516 | All | Exact |
| 620 | Portal 2 | 51 | 51 | All | Exact |
| 730 | Counter-Strike 2 | 1 | 1 | All | Exact |
| 4000 | Garry's Mod | 29 | 29 | All | Exact |
| 8930 | Sid Meier's Civilization V | 286 | 286 | All | Exact |
| 49520 | Borderlands 2 | 75 | 75 | All | Exact |
| 200260 | Batman: Arkham City GOTY | 64 | 64 | All | Exact |
| 203160 | Tomb Raider | 50 | 50 | All | Exact |
| 218620 | PAYDAY 2 | 1342 | 1342 | All | Exact |
| 227300 | Euro Truck Simulator 2 | 114 | 114 | All | Exact |
| 230410 | Warframe | 193 | 193 | All | Exact |
| 239140 | Dying Light | 78 | 78 | All | Exact |
| 241930 | Middle-earth™: Shadow of Mordor™ | 74 | 74 | All | Exact |
| 252330 | Slender: The Arrival | 21 | 21 | All | Exact |
| 252490 | Rust | 116 | 116 | All | Exact |
| 271590 | Grand Theft Auto V Legacy | 77 | 77 | All | Exact |
| 288160 | The Room | 5 | 5 | All | Exact |
| 289070 | Sid Meier's Civilization VI | 320 | 320 | All | Exact |
| 292030 | The Witcher 3: Wild Hunt — Remastered | 78 | 78 | All | Exact |
| 322170 | Geometry Dash | 547 | 547 | All | Exact |
| 356190 | Middle-earth™: Shadow of War™ | 72 | 72 | All | Exact |
| 377160 | Fallout 4 | 84 | 84 | All | Exact |
| 381210 | Dead by Daylight | 311 | 311 | All | Exact |
| 431960 | Wallpaper Engine | 17 | 17 | All | Exact |
| 489830 | The Elder Scrolls V: Skyrim Special Edition | 75 | 75 | All | Exact |
| 578080 | PUBG: BATTLEGROUNDS | 37 | 37 | All | Exact |
| 703080 | Planet Zoo | 38 | 38 | All | Exact |
| 945360 | Among Us | 33 | 33 | All | Exact |
| 990080 | Hogwarts Legacy | 45 | 45 | All | Exact |
| 1063730 | New World: Aeternum | 133 | 133 | All | Exact |
| 1085660 | Destiny 2 | 23 | 23 | All | Exact |
| 1091500 | Cyberpunk 2077 | 57 | 57 | All | Exact |
| 1128810 | RISK: Global Domination | 55 | 55 | All | Exact |
| 1172380 | STAR WARS Jedi: Fallen Order™ | 39 | 39 | All | Exact |
| 1174180 | Red Dead Redemption 2 | 51 | 51 | All | Exact |
| 1245620 | ELDEN RING | 42 | 42 | All | Exact |
| 1326470 | Sons Of The Forest | 32 | 32 | All | Exact |
| 1328670 | Mass Effect™ Legendary Edition | 127 | 127 | All | Exact |
| 1426210 | It Takes Two | 20 | 20 | All | Exact |
| 1599340 | Lost Ark | 156 | 156 | All | Exact |
| 1794680 | Vampire Survivors | 243 | 243 | All | Exact |
| 2062430 | BALL x PIT | 82 | 63 | Base | Exact |
| 2073850 | THE FINALS | 50 | 50 | All | Exact |
| 2767030 | Marvel Rivals | 49 | 49 | All | Exact |
| 2968420 | PowerWash Simulator 2 | 60 | 40 | Base | Exact |
| 3981100 | Leaf it Alone | 54 | 54 | All | Exact |
| 5037510 | Playrooms | 30 | 30 | All | Exact |
