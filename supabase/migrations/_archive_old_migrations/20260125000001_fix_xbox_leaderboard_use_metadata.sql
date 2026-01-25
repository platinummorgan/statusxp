-- Migration: Fix xbox_leaderboard_cache to read Gamerscore from metadata
-- This separates StatusXP (current_score) from platform scores (metadata)

BEGIN;

-- Update the view to calculate Gamerscore from metadata instead of current_score
CREATE OR REPLACE VIEW "public"."xbox_leaderboard_cache" AS
 SELECT "ua"."user_id",
    COALESCE("p"."xbox_gamertag", "p"."display_name", "p"."username", 'Player'::"text") AS "display_name",
    "p"."xbox_avatar_url" AS "avatar_url",
    "count"(*) AS "achievement_count",
    "count"(DISTINCT "a"."platform_game_id") AS "total_games",
    -- Calculate Gamerscore from metadata.current_gamerscore, fallback to completion %
    COALESCE(
      "sum"(("up"."metadata"->>'current_gamerscore')::integer),
      "sum"(ROUND(("up"."metadata"->>'max_gamerscore')::numeric * "up"."completion_percentage" / 100)::integer),
      0
    ) AS "gamerscore",
    "now"() AS "updated_at"
   FROM ((("public"."user_achievements" "ua"
     JOIN "public"."achievements" "a" ON ((("a"."platform_id" = "ua"."platform_id") AND ("a"."platform_game_id" = "ua"."platform_game_id") AND ("a"."platform_achievement_id" = "ua"."platform_achievement_id"))))
     JOIN "public"."profiles" "p" ON (("p"."id" = "ua"."user_id")))
     LEFT JOIN "public"."user_progress" "up" ON ((("up"."user_id" = "ua"."user_id") AND ("up"."platform_id" = "a"."platform_id") AND ("up"."platform_game_id" = "a"."platform_game_id"))))
  WHERE (("ua"."platform_id" = ANY (ARRAY[(10)::bigint, (11)::bigint, (12)::bigint])) AND ("p"."show_on_leaderboard" = true))
  GROUP BY "ua"."user_id", "p"."xbox_gamertag", "p"."display_name", "p"."username", "p"."xbox_avatar_url"
 HAVING ("count"(*) > 0)
  ORDER BY COALESCE(
      "sum"(("up"."metadata"->>'current_gamerscore')::integer),
      "sum"(ROUND(("up"."metadata"->>'max_gamerscore')::numeric * "up"."completion_percentage" / 100)::integer),
      0
    ) DESC, ("count"(*)) DESC, ("count"(DISTINCT "a"."platform_game_id")) DESC;

COMMENT ON VIEW "public"."xbox_leaderboard_cache" IS 'Xbox leaderboard showing all Xbox platforms (360, One, Series X/S). Gamerscore calculated from metadata.current_gamerscore with fallback to completion %.';

-- Backfill metadata.current_gamerscore from completion percentage for all Xbox games
UPDATE user_progress
SET metadata = jsonb_set(
  COALESCE(metadata, '{}'::jsonb),
  '{current_gamerscore}',
  to_jsonb(ROUND((metadata->>'max_gamerscore')::numeric * completion_percentage / 100)::integer)
)
WHERE platform_id IN (10, 11, 12)
  AND metadata->>'max_gamerscore' IS NOT NULL
  AND metadata->>'current_gamerscore' IS NULL;

COMMIT;
