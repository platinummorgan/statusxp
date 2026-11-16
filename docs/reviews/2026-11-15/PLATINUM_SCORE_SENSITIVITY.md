# PlayStation Completion Score Sensitivity

Analyzed November 15, 2026. The native and estimated rarity inputs produce small point differences for most lists under the current curve at unit weight. They also produce meaningful outliers and one definite ordering reversal on the sampled global leaderboard. The completion weight remains an open decision.

## Scoring method

The simulation uses the existing rarity curve, the live database's two-decimal score storage, and the canonical calculator's per-game integer rounding.

```text
completion_points(r) = round(0.5 + 11.5 * (1 - r / 100)^3, 2)
game_points = integer_cast(sum(included achievement points * rarity_multiplier))
```

Platinums currently contribute zero. This audit simulates enabling each qualifying earned Platinum at one unit of the current curve, once with native Platinum rarity and once with the minimum other required base-game trophy rarity. Every qualifying live Platinum multiplier was 1. The simulated award replaces its existing contribution inside the full game sum before rounding.

The leaderboard simulation holds the current cached global scores fixed, adds each game's incremental completion points, and compares the two projected boards. It uses existing confirmed Platinum unlocks. All 43 previously flagged inconsistent trophy-list identities are excluded, along with missing-group records and conflicting duplicate copies from the earlier audit.

The query runs in a read-only, repeatable-read transaction. Direct inspection confirmed the live column type, canonical calculation, and leaderboard ordering. The independently aggregated current game scores matched the live `calculate_statusxp_with_stacks` function for 10,617 game totals across three sampled users, with zero mismatches.

## Rare unlock rates under the actual curve

A doubling from 0.1% to 0.2% produces these stored point values.

| Rarity input | Completion points at unit weight |
| --- | --- |
| 0.1% | 11.97 XP |
| 0.2% | 11.93 XP |
| Difference | 0.04 XP |

The curve approaches a 12 XP cap at very low unlock percentages. The relative change in unlock rate therefore has a smaller effect on points than the ratio alone suggests. Small point differences can still cross the integer rounding boundary of a game's total.

## Point differences across trophy lists

Point loss means native-rarity points minus estimated-rarity points. These values precede rounding of the complete game total.

| Measure | All qualifying lists | Native Platinum below 1% |
| --- | --- | --- |
| Lists | 8,833 | 1,240 |
| Identical stored point values | 5,271 | 465 |
| Mean point loss | 0.0771 XP | 0.0734 XP |
| Median point loss | 0.00 XP | 0.03 XP |
| 90th percentile point loss | 0.21 XP | 0.18 XP |
| 95th percentile point loss | 0.40 XP | 0.31 XP |
| Maximum point loss | 4.13 XP | 1.12 XP |

Five of the original 1,245 below-1% lists are among the 43 inconsistent identities. The remaining rare cohort includes one zero-rarity list. Excluding that zero leaves 1,239 lists with the same displayed median, percentile, and maximum differences. Mean relative point loss in the below-1% cohort is approximately 0.62%, and its largest relative loss is approximately 9.50%.

## Outliers

| Game and platform | Native rarity | Estimate | Native points | Estimated points | Point loss |
| --- | --- | --- | --- | --- | --- |
| UFL on PS5 | 0.6% | 4.0% | 11.79 | 10.67 | 1.12 |
| Pummel Party on PS4 | 0.5% | 3.8% | 11.83 | 10.74 | 1.09 |
| EA SPORTS PGA TOUR on PS5 | 0.8% | 4.0% | 11.73 | 10.67 | 1.06 |
| DELTARUNE on PS4 | 21.0% | 48.8% | 6.17 | 2.04 | 4.13 |
| We Were Here Forever on PS4 | 11.1% | 29.3% | 8.58 | 4.56 | 4.02 |

The largest below-1% gaps remain material for those individual games. The largest point gap overall occurs outside that rare cohort.

## Global leaderboard comparison

The baseline contains 101 players. Fifty-five have qualifying earned Platinums, covering 13,577 earned completion records. The cached baseline was last refreshed at 17:00 UTC and the read-only simulation snapshot began at 17:22 UTC on November 15, 2026.

| Measure comparing native and estimated rarity | Result |
| --- | --- |
| Players with lower total points using the estimate | 48 |
| Median point loss across all 101 players | 0 XP |
| Largest player point loss | 148 XP |
| Total point loss across players | 940 XP |
| Players changing positions | 2 |
| Largest position change | 1 place |
| Strict ordering reversals between player pairs | 1 |
| Top 10 ordering changes | 0 |

The largest player loss belongs to an account with 4,922 qualifying Platinums. Its projected total changes from 184,407 XP with native rarity to 184,259 XP with estimated rarity, and it retains first place.

The two players below exchange positions without ties. Player labels refer to their baseline positions and contain no account identifiers.

| Player | Qualifying Platinums | Native score | Native position | Estimated score | Estimated position |
| --- | --- | --- | --- | --- | --- |
| Player 016 | 73 | 40,866 | 18 | 40,850 | 17 |
| Player 017 | 145 | 40,869 | 17 | 40,841 | 18 |

The production query orders by total score and leaves equal-score ordering unspecified. Audit positions use user ID as a deterministic tie break. Rank intervals confirm that this reversal occurs between distinct scores, so it is independent of equal-score display ordering.

Enabling Platinum scoring itself changes 16 baseline positions under native rarity and 17 under estimated rarity. Those are separate comparisons from the two-player movement caused specifically by changing the rarity input.

## Effects of per game rounding

Of 13,577 qualifying earned game completions, 855 lose integer points when the estimate replaces native rarity. The largest loss for one earned game is 4 XP.

The earned below-1% subset contains 451 completion records. Forty-three of those game totals lose a point, each losing 1 XP. Their combined loss is 43 XP out of the leaderboard's 940 XP total difference. These 43 affected earned records are separate from the 43 inconsistent trophy-list identities excluded from the study.

## Weight decision

At unit weight, the proxy has a small typical effect under the existing curve, including the below-1% cohort. The ranking comparison also demonstrates that a small point difference can change the order of nearby players.

Use these results to compare candidate completion weights. Multiplying an award increases its point difference, and per-game rounding and leaderboard positions require recalculation at the candidate weight. This audit establishes the unit-weight baseline and preserves the estimated rarity label for Xbox and Steam.

The simulation covers PlayStation completion contributions on the global board. Missing-group and inconsistent records are held outside the award comparison. Required membership and native rarity source coverage remain part of the implementation plan.

The [summary data](platinum-score-sensitivity-summary.json) includes anonymized projected scores and ranks. The [read-only SQL](PLATINUM_SCORE_SENSITIVITY.sql) reproduces the analysis against the current database with the same exclusion list. See the [rarity comparison](PLATINUM_RARITY_COMPARISON.md) and the [implementation plan](../../development/COMPLETION_RARITY_SCORING_PLAN.md).
