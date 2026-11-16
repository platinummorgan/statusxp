# Steam Base Achievement Mapping Pilot

Checked November 15, 2026 using read-only queries against stored achievement catalogs. Cross-platform matching can generate Steam base-game membership candidates from PlayStation's known grouping and can focus review on unmatched or differently described achievements.

## Matching results

The pilot excludes the PlayStation Platinum and matches other trophies to Steam achievements by unique names normalized for case and punctuation. Description matching uses the same normalization. These are candidate mappings with the verification gaps recorded below.

| Game | Steam AppID | PlayStation reference | Base trophies with unique Steam name matches | Add-on trophies with unique Steam name matches | Unmatched Steam achievements |
| --- | --- | --- | --- | --- | --- |
| The Witcher 3 | 292030 | PS4 NPWR07895_00 | 52 of 52 | 26 | 0 |
| Cyberpunk 2077 | 1091500 | PS5 NPWR24695_00 | 44 of 44 | 13 | 0 |
| Portal 2 | 620 | PS3 NPWR01719_00 | 50 of 50 | 0 | 1 |

All 78 Witcher 3 Steam achievements and all 57 Cyberpunk Steam achievements have matching PlayStation names with stored base or add-on membership. This provides candidate classifications even where Steam currently puts the entire list in its default group.

Portal 2 has an additional Steam achievement, `ACH.SUMMER_SALE`, named Talent Show. The stored requirement is to never lose a cube in Chamber 6 of the Mobility Gels co-op course. Its inclusion in the required Steam completion set needs an explicit classification using the release and content history.

## Requirement verification

For required base trophies, normalized descriptions match for 38 of 52 Witcher 3 trophies, 29 of 44 Cyberpunk trophies, and 49 of 50 Portal 2 trophies. Some Steam hidden achievements have empty stored descriptions. A checked example in each of Witcher 3 and Cyberpunk confirms that missing hidden descriptions account for part of this difference.

There are also visible wording differences to reconcile. Cyberpunk's Master Crafter says to craft three Tier 5 items on the selected PS5 list, while Steam's stored wording says to craft three Legendary items. Portal 2's Bridge Over Troubling Water describes the first Hard-Light Surfaces test on PlayStation and the first Hard Light Bridge test on Steam.

These cases call for edition, game-version, and requirement checks. Unique matching names generate candidates, while source grouping and requirement evidence establish the final required set. Record the stable Steam API name, reference platform and trophy ID, source group, evidence, and mapping revision.

## Implementation approach

Use verified PlayStation base groups or Xbox BaseGame membership as references for the corresponding Steam edition. Match individual achievements and preserve each source identity. Use description and requirement agreement where available, and reconcile missing descriptions, ambiguous names, platform-specific achievements, and edition differences through another authoritative list or targeted review.

Classify matched Steam achievements according to the verified reference requirements. Review extra Steam achievements explicitly. A Steam-only achievement can belong to the base game or later content, so its membership needs evidence before completing the required set.

The user confirmed that day-one base-game achievements count, including original Steam-exclusive achievements. DLC and achievements added after launch through updates or events are excluded from the completion requirement and estimated rarity. Apply this rule when classifying Portal 2's Talent Show after verifying its release timing.

Store the resulting membership once per Steam game and reuse it across users. Evaluate Steam completion using the player's Steam unlock IDs and compute estimated rarity from the required achievements' Steam percentages.

Existing repository grouping code provides candidate game associations. An archived similarity function matches achievement names and uses a percentage threshold to group games. The completion mapping needs the individual stable-ID links and requirement evidence described here.

Return to the [implementation plan](../../development/COMPLETION_RARITY_SCORING_PLAN.md).
