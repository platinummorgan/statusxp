# PlayStation Completion Rarity Comparison

Analyzed November 15, 2026 using stored PlayStation catalog data.

The lowest required trophy rarity is usually close to native Platinum rarity in this catalog. Across 8,876 distinct trophy lists with usable grouping and rarity data, the median absolute difference is 0.1 percentage points and 88.7% differ by at most one point. Exact matches account for 43.5%. Some games have substantial gaps, which supports retaining the estimated label for Xbox and Steam completion rarity.

## Comparison method

Read all 336,283 stored PlayStation achievement rows across PS5, PS4, PS3, and Vita. For each platform and trophy list, compare the native Platinum rarity against the minimum rarity among other trophies labeled with `trophy_group_id = default`. Exclude the Platinum from that minimum and exclude trophies assigned to other groups.

Require exactly one Platinum, known group membership, valid rarity percentages for the Platinum and every stored base-game trophy, and consistent DLC flags. Collapse matching copies of the same NPWR trophy-list identity across platform entries. Exclude duplicate identities whose required trophy IDs or rarity inputs disagree. Regional lists with different NPWR identifiers remain distinct.

The signed gap is the minimum required trophy percentage minus the Platinum percentage. For example, 5.1% against a 3.8% Platinum is a gap of 1.3 percentage points.

This is a catalog comparison using stored base-game labels and stored global rarity values. It measures the proposed proxy against PlayStation data. Xbox and Steam populations can produce different results.

## Coverage

| Measure | Count |
| --- | --- |
| Catalog trophy rows examined | 336,283 |
| Platform and game entries | 10,900 |
| Platinum entries | 9,698 |
| Entries excluded for missing Platinum group metadata | 783 |
| Qualifying platform and game entries | 8,915 |
| Duplicate copies collapsed | 23 |
| Conflicting duplicate trophy-list identities excluded | 8 |
| Distinct trophy lists compared | 8,876 |

The remaining 1,202 platform and game entries contain no Platinum. One compared list has zero Platinum rarity. Removing it leaves the displayed percentages and median unchanged at the precision used here.

## Results

| Absolute difference | Trophy lists | Share |
| --- | --- | --- |
| Exact match | 3,864 | 43.5% |
| At most 0.1 percentage points | 5,179 | 58.3% |
| At most 0.5 percentage points | 7,037 | 79.3% |
| At most 1 percentage point | 7,872 | 88.7% |
| At most 2 percentage points | 8,439 | 95.1% |

Threshold rows are cumulative. The median absolute gap is 0.1 percentage points, the 90th percentile is 1.2 points, and the 95th percentile is 2 points. The mean signed gap is approximately 0.45 points.

## Examples

| Game and platform | Native Platinum | Lowest stored base trophy | Gap in percentage points |
| --- | --- | --- | --- |
| FIFA 21 on PS5 | 0.1% | 0.1% | 0.0 |
| Returnal on PS5 | 1.5% | 1.6% | 0.1 |
| Deathloop on PS5 | 1.5% | 1.7% | 0.2 |
| ASTRO's PLAYROOM on PS5 | 4.1% | 4.8% | 0.7 |
| Final Fantasy XVI on PS5 | 3.8% | 5.1% | 1.3 |
| We Were Here Forever on PS5 | 9.6% | 26.6% | 17.0 |
| DELTARUNE on PS4 | 21.0% | 48.8% | 27.8 |

Six trophy lists, including the first five games above and Sackboy, were read independently after aggregation and matched the audit's Platinum rarity, minimum trophy rarity, and trophy count.

## Differences by Platinum rarity

| Native Platinum rarity | Lists | Median absolute gap | 90th percentile gap |
| --- | --- | --- | --- |
| Below 1% | 1,245 | 0.1 points | 0.5 points |
| 1% to below 5% | 1,282 | 0.3 points | 1.2 points |
| 5% to below 20% | 773 | 0.6 points | 3.4 points |
| 20% and above | 5,576 | 0.0 points | 1.0 points |

The high-rarity-percentage cohort forms most of the catalog, so the overall exact-match rate also reflects the catalog's game mix. Regional editions are separate trophy lists and can have different populations.

## Data quality exceptions

There are 43 lists where the stored minimum required trophy percentage is lower than the stored Platinum percentage. For a consistent population and correctly identified required set, Platinum earners must also have earned every required trophy. These records need grouping and rarity-freshness review before being used as calibration examples. Examples and source identifiers are saved in the summary data.

Using only PS4 and PS5 leaves 8,028 distinct lists, including 24 of those exceptions. The median absolute gap remains 0.1 points and 88.6% are within one point. This provides a sensitivity check against the older platform records.

## Scoring implication

Continue using native Platinum rarity for PlayStation. The agreed minimum required achievement method is a practical completion rarity estimate for Xbox and Steam, with an explicit estimated source. Individual achievement rarity describes one requirement, while native Platinum rarity reflects players satisfying the complete requirement set, so a game can have a substantial gap even when the individual inputs are accurate.

Validate required membership before selecting the minimum. Keep native and estimated rarity sources distinguishable and use the planned score preview to assess the impact of outliers under the chosen completion weighting.

See the [machine-readable summary](platinum-rarity-comparison-summary.json) for counts, platform breakdowns, exclusions, examples, and source list identifiers. Return to the [implementation plan](../../development/COMPLETION_RARITY_SCORING_PLAN.md).
