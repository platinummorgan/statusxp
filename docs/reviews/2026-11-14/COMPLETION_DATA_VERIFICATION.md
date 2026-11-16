# Completion Data Verification

Verified November 14, 2026. Implementation step 1 has live source results for Xbox Mythics and Steam achievement membership. Database design can use the fields below. Xbox completion rarity and Steam membership coverage remain explicit inputs to the next design step.

The saved [sample summaries](completion-data-samples.json) record response keys, counts, status codes, and selected public achievement identifiers. They omit account identifiers, credentials, and individual unlock timestamps. Live requests used existing connected accounts for authenticated APIs and public Steam pages for grouping.

## Xbox results

### Title history

The existing title-history endpoint returns Mythic information with contract version 2 and `Accept-Language: en-US`.

```text
GET https://titlehub.xboxlive.com/users/xuid(XUID)/titles/titlehistory/decoration/achievement
x-xbl-contract-version = 2
Accept-Language = en-US
Authorization = existing Xbox session
```

| Field | Observed behavior |
| --- | --- |
| `achievementSummary.mythicsUnlocked` | Account Mythic count. Samples returned 0, 1, and 13. |
| `titles[].achievement.isMythic` | Boolean earned status per listed game, including Xbox 360 games. |
| `titles[].achievement.baseGameCount` | Returned 1 for sampled achievement-enabled games, including games with 15 or 50 required achievements. |
| `titles[].achievement.baseGameCompleted` | Returned 0 for incomplete groups and 1 for completed groups. |
| `titles[].achievement.totalAchievements` | Returned 0 for several modern games with populated achievement catalogs. |

The base-game counters appear to count completion groups. Derive required and earned achievement counts from group membership arrays. Catalog and group counts are needed when title history reports a zero achievement total.

### Modern achievement groups

```text
GET https://achievements.xboxlive.com/users/xuid(XUID)/achievements?titleId=TITLE_ID&maxItems=1000
x-xbl-contract-version = 6
Accept-Language = en-US
Authorization = existing Xbox session
```

Contract version 6 adds `achievements[].groupIds`, individual achievement rarity, and a `completion` array. Each completion entry has `titleId` and a `groups` object keyed by group ID. Observed group fields include `groupType`, `groupName`, `achievementIds`, `unlockedAchievementIds`, `gamerscoreInGroup`, `unlockedGamerscore`, `isComplete`, and, for completed modern samples, `completedTime`.

| Sample | Catalog | Required base game | Result |
| --- | --- | --- | --- |
| Disney Dreamlight Valley | 15 achievements | 15 required, 4 unlocked | Incomplete BaseGame group |
| NBA 2K20 | 50 achievements | 50 required, 20 unlocked | Incomplete BaseGame group |
| Grounded | 45 achievements | 20 required, 14 unlocked | Original requirements separated from added achievements |
| Star Wars Outlaws | 59 achievements | 49 required, 49 unlocked | Completed BaseGame group with a completion time, 10 achievements outside the group |
| Road 96 | 12 achievements | 12 required, 12 unlocked | Completed BaseGame group with a completion time |

`possibleOnly=true` returned catalog rows with `NotStarted` and sentinel unlock dates even when the user's group had unlocked achievement IDs. Omitting that parameter returned confirmed achievement progress for the authenticated NBA 2K20 account. Keep catalog membership and player unlock provenance explicit when integrating the new contract.

A two-page request using `maxItems=2` returned a continuation token and the complete BaseGame membership block on both pages. The importer needs to preserve completion metadata while collecting and deduplicating achievement pages.

### Xbox 360

Fight Night Round 3 returned `isMythic=true` in title history. The modern contract version 6 achievement endpoint returned HTTP 200 with empty `achievements` and `completion` arrays for that game.

The legacy title catalog returned 8 definitions with catalog unlock flags unset. The existing legacy progress route with contract version 1 returned 8 earned achievements. Preserve the existing legacy catalog and progress merge, and import confirmed Mythic status from title history when modern group data is unavailable. This sample provides no native Mythic completion time.

The Walking Dead Season Two also reported an earned Mythic with `sourceVersion=1`, despite listing modern devices alongside Xbox 360. Classification must account for legacy source data and the existing platform guards.

### Xbox rarity and authentication limits

Sampled BaseGame completion blocks contain individual membership and unlock information, with no global Mythic completion percentage. The sampled account summary also provides no Mythic rarity percentage. A dedicated native rarity source remains unverified. The next design step must settle its source or an explicitly defined estimate.

Direct Xbox requests succeeded with refreshed sessions. No OpenXBL API key was available in the loaded local configuration, so OpenXBL group forwarding and its pagination remain unverified. Direct contract version 6 can supply modern group data independently of that fallback.

Two stored Xbox sessions initially returned 401. Normal OAuth, Xbox Live, and XSTS exchanges succeeded. Rotated refresh tokens and renewed session credentials were saved with account and prior-token comparisons. No game progress, achievement unlocks, scores, or leaderboard data were written during verification.

## Steam results

### Public group membership

The public page at `https://steamcommunity.com/achievements/APPID/?l=english` exposes structured membership without login. Extract and JSON-parse the `valve-ssr-data` script, then JSON-parse `renderContext.queryData`. Its queries include an achievement schema keyed by `['achievements', APPID, 'schema_v2']`.

The schema includes `appid`, `language`, `groups`, `schema_hash`, and `schema_version`. Groups expose `id`, `name`, `dlcappid`, `archived`, `ispublic`, `developeronly`, `order`, and `achievements`. Achievement entries expose `api_name`, `internal_key`, `groupid`, and `archived` alongside display fields.

This is a public page payload whose shape can change. Validate its schema and preserve source evidence and revision information during import.

| Game | AppID | Observed grouping | Implementation consequence |
| --- | --- | --- | --- |
| Vampire Survivors | 1794680 | 140 in group 0, 63 in Extra Content, 18 in Moonspell DLC, 22 in Foscari DLC | Supports explicit base, free added content, and paid DLC separation |
| Portal 2 | 620 | 29 Single Player and 22 Cooperative, both with zero DLC AppID, with no populated group 0 | Review which mode groups constitute the required base-game set |
| The Witcher 3 | 292030 | All 78 in group 0, including expansion achievements | Needs reviewed exclusions for base-game completion |
| Cyberpunk 2077 | 1091500 | All 57 in group 0 | Needs coverage review before treating membership as original-only |
| Deep Rock Galactic | 548430 | All 69 in group 0 | Membership is retrievable, original-only coverage needs review |
| Hades | 1145360 | All 49 in group 0 | Membership is retrievable, original-only coverage needs review |

Valve documents that existing achievements default into the base-game set. Its documentation also allows custom mode and event sets. The live samples therefore require membership review for both mixed default groups and custom non-DLC groups. [Steamworks achievement sets](https://partner.steamgames.com/doc/features/achievements/ach_guide)

### Schema and rarity joins

`GetSchemaForGame/v2` succeeded for Vampire Survivors, Portal 2, and The Witcher 3 with the stored Steam key. The sampled achievement schema fields contain names and display information, with no set or DLC membership. Every public-page `api_name` matched a Web API achievement `name` in these three samples.

`GetGlobalAchievementPercentagesForApp/v2/?gameid=APPID` succeeded without a key and returned matching rarity records for all 243, 51, and 78 achievements respectively. The percentages in these responses are strings and need numeric parsing with valid zero values preserved. The public page also contains global percentages keyed by achievement `internal_key`. [Steam Web API documentation](https://partner.steamgames.com/doc/webapi/ISteamUserStats)

For Vampire Survivors, the lowest rarity in group 0 was 12.2%, while Extra Content reached 1.7%. This demonstrates the score impact of selecting the correct required achievement set. These percentages are a snapshot and will change with player activity.

## Required follow through

- Choose the Xbox completion rarity source or estimation rule and the shared completion scoring weight.
- Design catalog membership storage around AppID and API name, with source group, revision, review state, and overrides.
- Review ambiguous Steam game sets before assigning completion eligibility, including the Portal 2 mode groups and mixed Witcher 3 list.
- Preserve optional completion dates and source-specific unlock provenance, including legacy Xbox fallback behavior.
- Verify OpenXBL behavior when its configured credentials are available, or define a fallback that preserves confirmed direct-source completion data.
- Include archived-achievement and membership-change policy in the next design step. The sampled groups contained no archived achievements to exercise that behavior live.

Return to the [implementation plan](../../development/COMPLETION_RARITY_SCORING_PLAN.md) for the tracked delivery order.
