-- Competition Simulation: Dex-Morgan vs X_imThumper_X
-- Using current leaderboard data

-- Get current stats
WITH current_stats AS (
  SELECT 
    display_name,
    total_statusxp,
    potential_statusxp,
    (potential_statusxp - total_statusxp) as remaining_statusxp
  FROM leaderboard_cache
  WHERE display_name IN ('Dex-Morgan', 'X_imThumper_X')
),
-- Simulate 1 week competition
competition_scenario AS (
  SELECT 
    display_name,
    total_statusxp as start_statusxp,
    potential_statusxp as locked_potential,
    remaining_statusxp as locked_remaining,
    -- Simulate gains over 1 week:
    -- Dex-Morgan: Grinds hard, gains 5,000 StatusXP
    -- X_imThumper_X: Casual play, gains 2,000 StatusXP
    CASE 
      WHEN display_name = 'Dex-Morgan' THEN 5000
      WHEN display_name = 'X_imThumper_X' THEN 2000
    END as statusxp_gained,
    -- Dex-Morgan adds 50 new games worth 25,000 potential (avg 500 per game)
    CASE 
      WHEN display_name = 'Dex-Morgan' THEN 25000
      ELSE 0
    END as new_potential_added
  FROM current_stats
)
SELECT 
  display_name,
  -- Starting state
  start_statusxp,
  locked_potential,
  locked_remaining,
  -- Ending state
  (start_statusxp + statusxp_gained) as end_statusxp,
  statusxp_gained,
  -- New games added mid-competition
  new_potential_added,
  (locked_potential + new_potential_added) as current_potential_in_leaderboard,
  -- COMPETITION SCORE (uses LOCKED values)
  ROUND((statusxp_gained::numeric / locked_remaining::numeric) * 100, 2) as competition_score_percent,
  -- What would happen WITHOUT locking (UNFAIR)
  ROUND((statusxp_gained::numeric / (locked_remaining::numeric + new_potential_added)) * 100, 2) as unfair_score_if_unlocked
FROM competition_scenario
ORDER BY competition_score_percent DESC;
