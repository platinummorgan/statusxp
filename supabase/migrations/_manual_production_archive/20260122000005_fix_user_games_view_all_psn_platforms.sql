-- Fix user_games view to include trophy breakdown for ALL PlayStation platforms
-- Currently only includes platform_id=1 (PS3), missing PS4 (2), PS5 (5), PSVITA (9)

CREATE OR REPLACE VIEW "public"."user_games" AS
 WITH "user_game_progress" AS (
         SELECT "up"."user_id",
            "up"."platform_id",
            "up"."platform_game_id",
            "up"."achievements_earned" AS "earned_trophies",
            "up"."total_achievements" AS "total_trophies",
            "up"."completion_percentage",
            "up"."current_score",
            "up"."last_played_at",
            ((('x'::"text" || "substr"("md5"(((("up"."platform_id")::"text" || '_'::"text") || "up"."platform_game_id")), 1, 15)))::bit(60))::bigint AS "game_title_id",
            "g"."name"
           FROM ("public"."user_progress" "up"
             JOIN "public"."games" "g" ON ((("g"."platform_id" = "up"."platform_id") AND ("g"."platform_game_id" = "up"."platform_game_id"))))
        ), "psn_trophy_breakdown" AS (
         SELECT "ua"."user_id",
            "ua"."platform_id",
            "ua"."platform_game_id",
            "count"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'bronze'::"text") THEN 1
                    ELSE NULL::integer
                END) AS "bronze_trophies",
            "count"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'silver'::"text") THEN 1
                    ELSE NULL::integer
                END) AS "silver_trophies",
            "count"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'gold'::"text") THEN 1
                    ELSE NULL::integer
                END) AS "gold_trophies",
            "count"(
                CASE
                    WHEN (("a"."metadata" ->> 'psn_trophy_type'::"text") = 'platinum'::"text") THEN 1
                    ELSE NULL::integer
                END) AS "platinum_trophies",
            "max"("ua"."earned_at") AS "last_trophy_earned_at",
            (EXISTS ( SELECT 1
                   FROM "public"."achievements" "a2"
                  WHERE (("a2"."platform_id" = "ua"."platform_id") AND ("a2"."platform_game_id" = "ua"."platform_game_id") AND (("a2"."metadata" ->> 'psn_trophy_type'::"text") = 'platinum'::"text")))) AS "has_platinum"
           FROM ("public"."user_achievements" "ua"
             JOIN "public"."achievements" "a" ON ((("a"."platform_id" = "ua"."platform_id") AND ("a"."platform_game_id" = "ua"."platform_game_id") AND ("a"."platform_achievement_id" = "ua"."platform_achievement_id"))))
          WHERE ("ua"."platform_id" IN (1, 2, 5, 9))
          GROUP BY "ua"."user_id", "ua"."platform_id", "ua"."platform_game_id"
        )
 SELECT "row_number"() OVER (ORDER BY "ugp"."user_id", "ugp"."platform_id", "ugp"."platform_game_id") AS "id",
    "ugp"."user_id",
    "ugp"."game_title_id",
    "ugp"."platform_id",
    "ugp"."name" AS "game_title",
    COALESCE("psn"."has_platinum", false) AS "has_platinum",
    COALESCE("psn"."bronze_trophies", (0)::bigint) AS "bronze_trophies",
    COALESCE("psn"."silver_trophies", (0)::bigint) AS "silver_trophies",
    COALESCE("psn"."gold_trophies", (0)::bigint) AS "gold_trophies",
    COALESCE("psn"."platinum_trophies", (0)::bigint) AS "platinum_trophies",
    COALESCE("psn"."last_trophy_earned_at", "ugp"."last_played_at") AS "last_trophy_earned_at",
    "ugp"."total_trophies",
    "ugp"."earned_trophies",
    "ugp"."completion_percentage" AS "completion_percent",
    "ugp"."last_played_at",
    "ugp"."current_score",
    "now"() AS "created_at",
    "now"() AS "updated_at"
   FROM ("user_game_progress" "ugp"
     LEFT JOIN "psn_trophy_breakdown" "psn" ON ((("psn"."user_id" = "ugp"."user_id") AND ("psn"."platform_id" = "ugp"."platform_id") AND ("psn"."platform_game_id" = "ugp"."platform_game_id"))));
