// Test if V2 StatusXP functions exist and deploy them if needed
import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config({ path: '.env' });

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY
);

async function deployV2Functions() {
  console.log('Checking if V2 StatusXP functions exist...');

  try {
    // Test if the function exists
    const { data, error } = await supabase.rpc('calculate_statusxp_with_stacks', {
      p_user_id: '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
    });

    if (error && error.message.includes('function calculate_statusxp_with_stacks')) {
      console.log('V2 functions not found, deploying...');

      // Deploy the functions
      const v2FunctionsSQL = `
-- Fix StatusXP Calculation for V2 Schema
-- Implements proper per-game calculation with stack multipliers for multi-platform games

-- Step 1: Calculate StatusXP per game with stack multipliers
-- Games on multiple Xbox platforms get reduced multiplier for subsequent stacks
CREATE OR REPLACE FUNCTION calculate_statusxp_with_stacks(p_user_id uuid)
RETURNS TABLE(
  platform_id bigint,
  platform_game_id text,
  game_name text,
  achievements_earned integer,
  statusxp_raw integer,
  stack_index integer,
  stack_multiplier numeric,
  statusxp_effective integer
) AS $$
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
    -- Assign stack index based on first played date for same game across platforms
    -- Xbox platforms 10,11,12 are considered stacks of same game
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
    CASE
      WHEN gs.stack_index = 1 THEN 1.0
      ELSE 0.5
    END::numeric as stack_multiplier,
    (gs.statusxp_raw * CASE WHEN gs.stack_index = 1 THEN 1.0 ELSE 0.5 END)::integer as statusxp_effective
  FROM game_stacks gs
  ORDER BY statusxp_effective DESC;
END;
$$ LANGUAGE plpgsql;

-- Step 2: Update leaderboard_cache with correct calculation
CREATE OR REPLACE FUNCTION refresh_statusxp_leaderboard()
RETURNS void AS $$
BEGIN
  INSERT INTO leaderboard_cache (user_id, total_statusxp, total_game_entries, last_updated)
  SELECT
    p.id as user_id,
    COALESCE(game_totals.total_statusxp, 0) as total_statusxp,
    COALESCE(game_totals.total_games, 0) as total_game_entries,
    NOW() as last_updated
  FROM profiles p
  LEFT JOIN (
    SELECT
      ua.user_id,
      COUNT(DISTINCT (ua.platform_id, ua.platform_game_id)) as total_games,
      SUM(statusxp_effective) as total_statusxp
    FROM user_achievements ua
    JOIN LATERAL (
      SELECT statusxp_effective
      FROM calculate_statusxp_with_stacks(ua.user_id)
      WHERE platform_id = ua.platform_id
        AND platform_game_id = ua.platform_game_id
      LIMIT 1
    ) calc ON true
    GROUP BY ua.user_id
  ) game_totals ON game_totals.user_id = p.id
  WHERE p.show_on_leaderboard = true
    AND p.merged_into_user_id IS NULL
  ON CONFLICT (user_id)
  DO UPDATE SET
    total_statusxp = EXCLUDED.total_statusxp,
    total_game_entries = EXCLUDED.total_game_entries,
    last_updated = EXCLUDED.last_updated;
END;
$$ LANGUAGE plpgsql;
`;

      const { error: deployError } = await supabase.rpc('exec_sql', { sql: v2FunctionsSQL });

      if (deployError) {
        console.error('Failed to deploy V2 functions:', deployError);
        return false;
      }

      console.log('✅ V2 StatusXP functions deployed successfully');
      return true;
    } else {
      console.log('✅ V2 StatusXP functions already exist');
      return true;
    }
  } catch (error) {
    console.error('Error checking/deploying V2 functions:', error);
    return false;
  }
}

// Test the functions
async function testV2Functions() {
  try {
    console.log('Testing V2 StatusXP calculation...');
    const { data, error } = await supabase.rpc('calculate_statusxp_with_stacks', {
      p_user_id: '8fef7fd4-581d-4ef9-9d48-482eff31c69d'
    });

    if (error) {
      console.error('Error testing calculate_statusxp_with_stacks:', error);
      return false;
    }

    console.log('✅ calculate_statusxp_with_stacks works');
    console.log('Sample results:', data?.slice(0, 3));

    // Test refresh function
    const { error: refreshError } = await supabase.rpc('refresh_statusxp_leaderboard');

    if (refreshError) {
      console.error('Error testing refresh_statusxp_leaderboard:', refreshError);
      return false;
    }

    console.log('✅ refresh_statusxp_leaderboard works');
    return true;
  } catch (error) {
    console.error('Error testing V2 functions:', error);
    return false;
  }
}

async function main() {
  const deployed = await deployV2Functions();
  if (deployed) {
    await testV2Functions();
  }
}

main().catch(console.error);