# Activity feed audit and repair — September 20, 2026

Audited all 467 stored stories (February 12–September 20), including expired history. This is not a count of currently visible posts.

## Findings

- 145 stories used “Multiple games”; 85 had no game title; five omitted an available title from their prose.
- “Keep it up” appeared 113 times, “crushed it” 79 times, “on fire” 25 times, and “Keep shining” 15 times.
- Forty numeric events started at zero. Some were legitimate initial imports; zero alone is not proof of a bug.
- Infernofeuer1 had repeated zero trophy snapshots followed by full lifetime totals, incorrectly announced as fresh wins. Snapshot creation ignored trophy-count RPC errors.
- Context queries were unpaginated. A historical Edhim story claimed 45 games; replay found 150 trophy lists, across 145 distinct names.
- Steam used a representative latest game for multi-game changes. Generic StatusXP context could come from another platform. Xbox built new totals by adding imported achievement scores rather than requiring agreement with observed total changes.
- Sixty output tokens truncated stories. Conflicting instructions demanded detailed counts and before/after totals inside 150 characters. Validation stripped non-Latin titles to empty strings, allowing omissions.
- Rare trophy detection read metadata.rarity, but current PSN writes rarity_global.

## Implementation

Snapshot failures no longer become zero counts. Incomplete or invalid counts skip feed work; trophy synchronization itself continues. Snapshots are retained rather than deleting other snapshots from a five-minute window. Xbox totals, achievement windows, and game context are paginated.

The fact builder requires source-specific snapshot deltas to match the complete imported achievement set. Reset totals, repeated imports, missing titles/definitions, failed queries, and partial data do not produce stories. One story combines PSN platinum and other trophy changes. The context lists up to three actual game names, with remaining counts; distinct trophy lists remain distinct even when titles match. Rare unlocks use validated positive rarity_global below 10 percent. Mixed-game updates identify the platinum game separately.

Initial collections and windows containing unlocks older than seven days are explicitly labeled library updates. Their wording does not imply those trophies were just earned. The seven-day classification is a conservative editorial rule, not an assessment of legitimacy.

AI writes a short English template around immutable player, activity, game, and extra-fact placeholders. Recent stories are provided to discourage repetitive openings. Missing/repeated placeholders, numeric inventions, unsupported record/speed wording, and incomplete responses fall back to complete factual prose. No model migration or new API dependency was needed. Completion handling follows the [OpenAI API reference](https://developers.openai.com/api/reference/resources/chat).

Unverified global StatusXP cache changes are no longer attributed to a specific platform or game. Reintroducing earned StatusXP requires authoritative per-sync scoring evidence. User stats and leaderboards are not changed.

## Live data repair

- Corrected #531 to the actual inFAMOUS 2 gain: one platinum, one Gold, one Silver, three Bronze.
- Corrected #547 to PAINT BALL: two platinums and 22 Gold across two lists.
- Hid six redundant/incorrect stories: #532, #542, #543, #544, #545, #548. None were deleted.
- Corrected #535 to name Hades and Oblivion Remastered, identify the Hades platinum, and include the 6.1% rare trophy.
- Corrected #540 and #541 as historical library updates, with named examples and complete list counts.
- All edits used expected original story text to avoid overwriting concurrent changes.
- Verified the application's grouped-feed RPC returns the five corrected stories and none of the six hidden entries.

Rollback and evidence files are local under output/feed-audit: feed-before.json, repair-rollback.json, repair-plan.json, repair-result.json, context-repair-plan.json (includes originals), and visible-feed-verification.json. Historical stories without sufficient evidence were left unchanged.

## Validation and operational limits

All 34 service tests passed, including 13 new regression tests. Real database replay correctly retained ordinary Dex-Morgan progress and rejected the false Infernofeuer1 bursts. One live AI preview preserved the verified facts. Tests also ran against an isolated copy of the production revision and its clean installed dependencies.

Conservative verification can omit a legitimate feed story when metadata or snapshots are incomplete, or during conflicting syncs; it does not retry the missed story later. Seven-day duplicate suppression checks recent matching totals before generation, but is not a database-level atomic uniqueness guarantee. The AI template protects supplied names and counts; free prose is constrained by prompting and validation, not a general proof of semantic correctness.

Production was packaged from deployed revision d54b4d49b2fa209faa2f03affa1ea2374e398323 with only the three feed runtime modules and two feed test files overlaid. No unrelated local changes, secrets, or installed node_modules were uploaded. Initial builds failed because the nested upload inherited a lockfile exclusion; the clean release includes the lockfile explicitly. The working production deployment remained available during failed builds.

Final Railway deployment: e4f60dac-6fa8-43d6-b42c-25dc272188f3, SUCCESS. Railway healthcheck and public /health both passed. Remote SHA-256 hashes of all three feed runtime modules match the local files exactly. This was a direct isolated deployment. The source changes are also being released to main from a clean worktree based on the production revision so future GitHub deployments preserve the fix. No mobile version bump or app-store release is required for this backend-only change.
