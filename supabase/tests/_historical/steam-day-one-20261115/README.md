# Historical Steam day-one tests

These assertions target the retired manual/console-equivalent membership workflow and Steam's previous 5× completion weighting. They are retained for auditing or a deliberate rollback of that complete implementation; do not run them against the current native-set policy.

Current regression: `supabase/tests/native_steam_completion_sets.sql`. It tests native base/full-set fallback membership, 1× Steam scoring, permissions, native unlock qualification, revisions and existing leaderboard integrations. See `docs/reviews/2026-11-16/NATIVE_STEAM_COMPLETION_SETS_RELEASE.md`.
