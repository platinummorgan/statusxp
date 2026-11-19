# Phase 1 Entity and Routing Decisions

**Decision date:** August 12, 2026  
**Status:** Approved for implementation

## Outcome

StatusXP will use one cross-platform library and platform-scoped canonical entity routes. The first Phase 1 release will establish a durable game hub without attempting to deliver the entire public-profile, community, or content roadmap at once.

## Canonical personal library

- `/games` becomes the canonical personal library and uses `UnifiedGamesListScreen` and `UnifiedGamesRepository`.
- The useful filters and interactions from the legacy PlayStation-oriented games screen will be migrated into the unified experience where they still add value.
- `/unified-games` remains as a compatibility redirect for at least one release and is instrumented before removal.
- The legacy `GamesListScreen` is retired only after route analytics, navigation tests, and feature parity confirm it is safe.

## Canonical entity identifiers

Database V2 composite identifiers are authoritative:

- Game: `(platform_id, platform_game_id)`
- Achievement: `(platform_id, platform_game_id, platform_achievement_id)`
- Profile internally: `profiles.id` UUID

Titles, platform labels, cover URLs, achievement names, and other display metadata must be loaded from repositories. They must not be trusted from query-string parameters.

Application code will represent a game reference as a typed value containing `platformId` and `platformGameId`. Achievement references add `platformAchievementId`.

## Public platform URL codes

URLs use stable readable platform codes, mapped centrally to numeric database IDs:

| URL code | Platform ID |
|---|---:|
| `ps5` | 1 |
| `ps4` | 2 |
| `steam` | 4 |
| `ps3` | 5 |
| `psvita` | 9 |
| `xbox360` | 10 |
| `xboxone` | 11 |
| `xboxseries` | 12 |

Unknown platform codes fail with a deliberate not-found state. The registry is tested so database and route mappings cannot silently drift.

## Canonical URLs

```text
/games/:platformCode/:platformGameId
/games/:platformCode/:platformGameId/achievements
/games/:platformCode/:platformGameId/achievements/:platformAchievementId
```

Identifiers must be URL encoded and decoded at the routing boundary. Existing singular `/game/:gameId`, query-string-driven achievement routes, and imperative navigation remain compatibility paths until their callers are migrated and measured.

## Public profile handles

Phase 3 will add a dedicated nullable `profiles.public_handle`; the existing `username` must not automatically become a public URL because it may have been derived from an email address.

The future handle contract is:

- Explicitly chosen or generated only through a privacy-safe onboarding flow
- Case-insensitive unique, stored in normalized lowercase form
- 3–30 characters using `a-z`, `0-9`, `_`, and `-`
- Checked against a reserved-word list
- Independent of display names and connected platform names
- Supported by handle history or redirects when renamed

Public profile visibility and RLS rules must be approved before `/u/:handle` ships.

## First canonical game-hub slice

The first implementation slice contains:

1. A tested platform-code registry and typed `GameRef`.
2. Repository loading by the composite game key.
3. The canonical `/games/:platformCode/:platformGameId` route.
4. A responsive overview shell using canonical title, cover, platform, progress, StatusXP, and achievement breakdown data.
5. Deliberate loading, partial-data, not-found, and error states.
6. Navigation into the hub from the unified personal library and global catalog.
7. Web deep-link, widget, and navigation tests plus entity-view analytics.

The slice explicitly excludes public profiles, full global aggregate statistics, guides, Gaming Pulse, franchise grouping, and removal of compatibility routes.

## Acceptance criteria

- A copied canonical game URL resolves without prior navigation state.
- The route loads display metadata from the repository using both platform and game identifiers.
- Two games with the same platform game ID on different platforms cannot collide.
- Anonymous, signed-in non-owner, and signed-in owner states are handled intentionally where data access allows them.
- Library and catalog cards open the same canonical destination.
- Invalid platform codes and missing games show useful not-found states.
- Compatibility routes remain functional and measurable during migration.
- Automated tests cover every platform mapping, encoding, repository lookup, and primary navigation path.

## Following slice

After the game overview is validated, add the canonical achievement detail route and embed existing comments and co-op help within it. That work must reuse the same platform-scoped identifier contract.
