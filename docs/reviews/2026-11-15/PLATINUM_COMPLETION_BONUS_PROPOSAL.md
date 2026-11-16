# Completion Rarity Bonus Proposal

Prepared November 15, 2026 after the user supplied the earlier completion-bonus discussion. The intended feature includes an additional rarity-based completion reward. At the time of the preview, the PlayStation release counted native Platinum rarity through the ordinary 1x curve. The user subsequently selected 5x on the rarity component, retaining the 0.5 XP floor. The comparisons below record the pre-release preview.

The supplied discussion describes ordinary achievement XP continuing alongside an additional completion reward for Platinums, Mythics, and Steam base-game completion. It also calls for understandable score breakdowns and hypothetical score previews. The example of 197 Platinums adding 10,483 XP illustrates presentation and does not specify a bonus formula.

## Recommended starting model

Apply a completion weight to the existing rarity component while retaining the 0.5 XP floor.

```text
Completion award = round(0.5 + 11.5 * completion_weight * (1 - rarity / 100)^3, 2)
Additional bonus = completion award - currently included completion points
```

The selected weight is 5. A weight of 10 is retained as a historical comparison; the preview baseline uses weight 1.

Use native Platinum rarity on PlayStation and the agreed minimum required achievement percentage, labeled Estimated rarity, for Xbox and Steam. The award contributes once per earned completion. For the existing Platinum row, replace its current points with the new total and expose the difference as the additional bonus in score breakdowns.

## Example completion awards

| Unlock percentage | Current 1x | Proposed 5x | Additional 5x bonus | Comparison 10x |
| --- | --- | --- | --- | --- |
| 0.1% | 11.97 | 57.83 | 45.86 | 115.16 |
| 0.2% | 11.93 | 57.66 | 45.73 | 114.81 |
| 1% | 11.66 | 56.29 | 44.63 | 112.08 |
| 5% | 10.36 | 49.80 | 39.44 | 99.10 |
| 10% | 8.88 | 42.42 | 33.54 | 84.34 |
| 50% | 1.94 | 7.69 | 5.75 | 14.88 |
| 90% | 0.51 | 0.56 | 0.05 | 0.62 |
| 99% | 0.50 | 0.50 | 0.00 | 0.50 |

At 5x, a 1% completion is worth about 113 times a 99% completion. The high-unlock-rate floor stays at 0.5 XP. This weighting increases the contribution of rare completions without scaling the floor awarded to every completion.

## Read only leaderboard preview

The preview uses the 101-player global leaderboard after native Platinum inclusion, existing earned PlayStation Platinums, two-decimal award storage, and per-game integer rounding. It adds only the difference between the candidate award and already-counted Platinum points.

| Metric | Proposed 5x | Comparison 10x |
| --- | --- | --- |
| Players gaining extra points | 55 | 55 |
| Combined additional XP | 113,805 | 256,167 |
| Largest player increase | 15,191 | 34,180 |
| Audit positions changed | 36 | 62 |
| Largest position change | 3 | 8 |

Positions use score descending with user ID as a deterministic tie break. A sampled account with 140 completions, including 25 at 1% or below and none at 90% or above, rises from sixth to fourth under the 5x proposal. Accounts with large collections can also have substantial rare completion histories, so the preview reports rarity counts alongside their gains.

The source comparison in the [preview data](platinum-completion-bonus-preview.json) sets aside the earlier 43 inconsistent identities. For the remaining 1,240 lists below 1%, native-versus-estimated rarity has a median point difference of 0.17 XP and a 95th percentile difference of 1.52 XP at 5x. The corresponding 10x differences are 0.34 and 3.04 XP. These are award-level differences before complete-game rounding.

## Decision and implementation

Confirmed by the user: use 5x on the rarity component for Platinum, Mythic, and Steam base-game 100% awards. Preserve the current individual achievement formula and the estimated source labels.

Apply the selected award calculation consistently in PSN sync and database enforcement, backfill historical completion awards, refresh earned and potential totals, and verify score breakdowns and full versus per-user rounding. Use the same completion rule when Xbox and Steam completion records are implemented.

The selected 5x rule is now live for PlayStation. The [release verification](PSN_PLATINUM_SCORING_RELEASE.md) confirms the previewed 113,805 additional XP and clean source-to-cache totals. Xbox and Steam completion awards remain pending implementation.

Return to the [implementation plan](../../development/COMPLETION_RARITY_SCORING_PLAN.md).
