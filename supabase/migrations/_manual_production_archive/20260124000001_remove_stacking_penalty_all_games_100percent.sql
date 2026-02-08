-- Migration: Remove stacking penalty from StatusXP calculation
-- Purpose: All games should count at 100%, no 50% penalty for duplicates
-- Date: 2026-01-24

-- Fix: Update calculate_statusxp_with_stacks to remove stack multiplier penalty
-- All games now count at full value (100%) regardless of duplicate game IDs

CREATE OR REPLACE FUNCTION "public"."calculate_statusxp_with_stacks"("p_user_id" "uuid") RETURNS TABLE("platform_id" bigint, "platform_game_id" "text", "game_name" "text", "achievements_earned" integer, "statusxp_raw" integer, "stack_index" integer, "stack_multiplier" numeric, "statusxp_effective" integer)
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  RETURN QUERY
  WITH game_raw_xp AS (
    -- Calculate raw StatusXP per game (sum of earned achievements)
    SELECT 
      ua.platform_id,
      ua.platform_game_id,
      g.name as game_name,
      COUNT(*)::integer as achievements_earned,
      SUM(a.base_status_xp)::integer as statusxp_raw
    FROM user_achievements ua
    JOIN achievements a ON 
      a.platform_id = ua.platform_id
      AND a.platform_game_id = ua.platform_game_id
      AND a.platform_achievement_id = ua.platform_achievement_id
    JOIN games g ON 
      g.platform_id = ua.platform_id
      AND g.platform_game_id = ua.platform_game_id
    WHERE ua.user_id = p_user_id
      AND a.include_in_score = true
    GROUP BY ua.platform_id, ua.platform_game_id, g.name
  ),
  game_stacks AS (
    -- Assign stack index for reference, but no longer apply penalty
    -- Xbox platforms 10,11,12 with same game ID would be stacked, but penalty removed
    SELECT 
      grx.*,
      ROW_NUMBER() OVER (
        PARTITION BY 
          CASE 
            -- Group Xbox 360/One/Series as same game
            WHEN grx.platform_id IN (10, 11, 12) THEN grx.platform_game_id
            -- PSN and Steam are always unique
            ELSE grx.platform_id::text || '_' || grx.platform_game_id
          END
        ORDER BY up.first_played_at NULLS LAST, grx.platform_id
      )::integer as stack_index
    FROM game_raw_xp grx
    LEFT JOIN user_progress up ON 
      up.user_id = p_user_id
      AND up.platform_id = grx.platform_id
      AND up.platform_game_id = grx.platform_game_id
  )
  SELECT 
    gs.platform_id,
    gs.platform_game_id,
    gs.game_name,
    gs.achievements_earned,
    gs.statusxp_raw,
    gs.stack_index,
    1.0::numeric as stack_multiplier,
    gs.statusxp_raw as statusxp_effective
  FROM game_stacks gs
  ORDER BY statusxp_effective DESC;
END;
$$;

ALTER FUNCTION "public"."calculate_statusxp_with_stacks"("p_user_id" "uuid") OWNER TO "postgres";
