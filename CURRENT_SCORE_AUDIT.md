# user_progress.current_score Audit (Definitive)

## What writes to `user_progress.current_score`
**Runtime sync (code):**
- Xbox sync writes per‑game gamerscore to `current_score`.
  - Source: [sync-service/xbox-sync.js](sync-service/xbox-sync.js#L862)

**One‑off SQL scripts (manual/maintenance):**
- These scripts overwrite `current_score` with **StatusXP** (not gamerscore):
  - [supabase/migrations/20260125000003_recalculate_statusxp_all_users_all_platforms.sql](supabase/migrations/20260125000003_recalculate_statusxp_all_users_all_platforms.sql#L1)
  - [supabase/migrations/20260125000006_recalculate_user_progress_exponential.sql](supabase/migrations/20260125000006_recalculate_user_progress_exponential.sql#L1)
  - [fix_all_users_current_score.sql](fix_all_users_current_score.sql)
  - [fix_all_users_bulk.sql](fix_all_users_bulk.sql)
  - [fix_robo_ripper_statusxp.sql](fix_robo_ripper_statusxp.sql)

## Definitive decision (recommended)
**`user_progress.current_score` must mean platform native score**
- Xbox: per‑game gamerscore from the Xbox API
- PSN: trophy points per game (if available)
- Steam: 0 (no score system)

StatusXP should **never** be stored in `current_score`. It already has a canonical source: `calculate_statusxp_with_stacks()` and `leaderboard_cache`.

## Immediate actions taken
- None in runtime data pipeline; this file documents the decision.

## Required follow‑ups (to enforce definites)
1) **Stop using `current_score` for StatusXP** in any future scripts.
2) **Update DB comment** to reflect platform score semantics.
3) **Compute gamerscore from achievements only for validation**, not as the display source.

## Validation queries
Use these to identify sync gaps (API gamerscore vs earned achievements scores):

```sql
-- Compare per‑user totals (Xbox only)
WITH api_score AS (
  SELECT user_id, SUM(current_score)::bigint AS api_gamerscore
  FROM public.user_progress
  WHERE platform_id IN (10,11,12)
  GROUP BY user_id
),
earned_score AS (
  SELECT ua.user_id, SUM(COALESCE(a.score_value, 0))::bigint AS earned_gamerscore
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.platform_id IN (10,11,12)
  GROUP BY ua.user_id
)
SELECT p.id, p.xbox_gamertag, api_score.api_gamerscore, earned_score.earned_gamerscore,
       (api_score.api_gamerscore - earned_score.earned_gamerscore) AS delta
FROM public.profiles p
LEFT JOIN api_score ON api_score.user_id = p.id
LEFT JOIN earned_score ON earned_score.user_id = p.id
WHERE p.xbox_gamertag IS NOT NULL
ORDER BY ABS(COALESCE(api_score.api_gamerscore,0) - COALESCE(earned_score.earned_gamerscore,0)) DESC;
```

```sql
-- Per‑game delta for a single user (replace :user_id)
WITH api_game AS (
  SELECT user_id, platform_id, platform_game_id, current_score::bigint AS api_gamerscore
  FROM public.user_progress
  WHERE platform_id IN (10,11,12) AND user_id = :user_id
),
earned_game AS (
  SELECT ua.user_id, ua.platform_id, ua.platform_game_id,
         SUM(COALESCE(a.score_value, 0))::bigint AS earned_gamerscore
  FROM public.user_achievements ua
  JOIN public.achievements a
    ON a.platform_id = ua.platform_id
   AND a.platform_game_id = ua.platform_game_id
   AND a.platform_achievement_id = ua.platform_achievement_id
  WHERE ua.platform_id IN (10,11,12) AND ua.user_id = :user_id
  GROUP BY ua.user_id, ua.platform_id, ua.platform_game_id
)
SELECT g.platform_game_id, COALESCE(api_gamerscore,0) AS api_gamerscore,
       COALESCE(earned_gamerscore,0) AS earned_gamerscore,
       (COALESCE(api_gamerscore,0) - COALESCE(earned_gamerscore,0)) AS delta
FROM api_game g
LEFT JOIN earned_game e
  ON e.user_id = g.user_id
 AND e.platform_id = g.platform_id
 AND e.platform_game_id = g.platform_game_id
ORDER BY ABS(COALESCE(api_gamerscore,0) - COALESCE(earned_gamerscore,0)) DESC;
```
