# First positive live Xbox Mythic sync

Verified November 16, 2026, after the user reported a newly synchronized account showing Mythics. This investigation used read-only database/API queries; it did not start a sync or alter scores, awards, membership, or native earned dates.

## Result

The completed normal Xbox sync recorded **seven native Mythics**. Dashboard statistics and the Xbox all-time leaderboard both return **7**; the account is ranked first at the time of the check. Every award has persisted `mythic_last_reported: true` and exactly one completion score event. There are no duplicate completion contributions.

The account's cached **23,876 StatusXP** equals the canonical total across 304 game/platform entries. The seven awards contribute **122.50 completion XP before existing per-game rounding and stack rules**. This is a component sum, not a measured before/after account-score increase.

| Title | Required native base IDs | Estimated rarity | Completion XP | Coverage |
| --- | ---: | ---: | ---: | --- |
| The First Descendant | 24 | 4.03% | 51.32 | All required IDs join; minimum and 5× formula match |
| Persona 5 Royal | 52 | 3.60% | 52.01 | All required IDs join; minimum and 5× formula match |
| The Walking Dead: Michonne - Ep. 1, In Too Deep | 21 | 33.81% | 17.17 | All required IDs join; minimum and 5× formula match |
| Dead Space Ignition | Unavailable | Unavailable | 0.50 | Native Mythic confirmed; base membership/rarity pending |
| BAYONETTA | Unavailable | Unavailable | 0.50 | Native Mythic confirmed; base membership/rarity pending |
| The Walking Dead: Season Two | Unavailable | Unavailable | 0.50 | Native Mythic confirmed; base membership/rarity pending |
| The Walking Dead | Unavailable | Unavailable | 0.50 | Native Mythic confirmed; base membership/rarity pending |

The first three awards have genuine stored completion dates. The remaining four have null dates; no sync-time completion date was fabricated. Their missing native base grouping makes a rarity estimate uncertain, so the implemented unavailable-rarity floor is used rather than the minimum over a potentially DLC-contaminated full achievement list. These four still count because their native Mythic status is confirmed independently of rarity coverage.

## What this establishes

- Positive real-account import works through normal sync, without manual grants or inferring an award from Gamerscore/achievement percentage.
- Modern verified base membership, minimum rarity, 5× component weighting, one-event scoring, dashboard statistics and all-time leaderboard counts agree.
- Legacy awards are retained while unavailable grouping, rarity and dates remain explicitly unknown.

The remaining coverage work is obtaining authoritative base membership and rarity for those four legacy titles. This check did not log into the other user's account or visually test their phone, replay provider calls, or establish that an incompletely earned DLC list leaves a real completed base award unaffected. Synthetic regressions cover that DLC exclusion behavior; live partial-DLC coverage remains a separate case.

[Sanitized verification](xbox-positive-mythic-verification.json). Raw account-bound investigation output remains in the ignored local audit directory and is not committed.
