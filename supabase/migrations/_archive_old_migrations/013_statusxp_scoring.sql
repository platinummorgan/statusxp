-- Migration: 013_statusxp_scoring.sql
-- Created: 2025-12-06
-- Description: StatusXP scoring system based on platform-specific rarity

-- Function to calculate StatusXP multiplier from rarity percentage
CREATE OR REPLACE FUNCTION get_rarity_multiplier(rarity_percent numeric)
RETURNS numeric AS $$
BEGIN
  IF rarity_percent IS NULL THEN
    RETURN 1.0; -- Default to Common if no rarity data
  END IF;
  
  IF rarity_percent <= 1.0 THEN
    RETURN 3.0; -- Ultra Rare
  ELSIF rarity_percent <= 5.0 THEN
    RETURN 2.25; -- Very Rare
  ELSIF rarity_percent <= 10.0 THEN
    RETURN 1.75; -- Rare
  ELSIF rarity_percent <= 25.0 THEN
    RETURN 1.25; -- Uncommon
  ELSE
    RETURN 1.0; -- Common
  END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to calculate StatusXP for an achievement
CREATE OR REPLACE FUNCTION get_achievement_statusxp(
  platform_param text,
  trophy_type_param text,
  rarity_percent numeric
)
RETURNS integer AS $$
DECLARE
  base_value integer := 100;
  multiplier numeric;
BEGIN
  -- Exclude PlayStation Platinums from scoring
  IF platform_param = 'psn' AND trophy_type_param = 'platinum' THEN
    RETURN 0;
  END IF;
  
  -- Get rarity multiplier
  multiplier := get_rarity_multiplier(rarity_percent);
  
  -- Calculate StatusXP
  RETURN (base_value * multiplier)::integer;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- View to show user's StatusXP scores
CREATE OR REPLACE VIEW user_statusxp_scores AS
SELECT 
  ua.user_id,
  a.platform,
  a.game_title_id,
  gt.name as game_name,
  a.id as achievement_id,
  a.name as achievement_name,
  a.psn_trophy_type,
  a.rarity_global,
  a.is_dlc,
  get_achievement_statusxp(a.platform, a.psn_trophy_type, a.rarity_global) as statusxp,
  ua.unlocked_at
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
JOIN game_titles gt ON a.game_title_id = gt.id
WHERE get_achievement_statusxp(a.platform, a.psn_trophy_type, a.rarity_global) > 0; -- Exclude platinums

-- View to show user's total StatusXP by platform
CREATE OR REPLACE VIEW user_statusxp_totals AS
SELECT 
  user_id,
  platform,
  COUNT(*) as achievements_unlocked,
  SUM(statusxp) as total_statusxp,
  COUNT(*) FILTER (WHERE is_dlc = false) as base_game_achievements,
  SUM(statusxp) FILTER (WHERE is_dlc = false) as base_game_statusxp,
  COUNT(*) FILTER (WHERE is_dlc = true) as dlc_achievements,
  SUM(statusxp) FILTER (WHERE is_dlc = true) as dlc_statusxp
FROM user_statusxp_scores
GROUP BY user_id, platform;

-- View to show user's overall StatusXP
CREATE OR REPLACE VIEW user_statusxp_summary AS
SELECT 
  user_id,
  SUM(achievements_unlocked) as total_achievements,
  SUM(total_statusxp) as total_statusxp,
  SUM(base_game_achievements) as base_game_achievements,
  SUM(base_game_statusxp) as base_game_statusxp,
  SUM(dlc_achievements) as dlc_achievements,
  SUM(dlc_statusxp) as dlc_statusxp
FROM user_statusxp_totals
GROUP BY user_id;

COMMENT ON FUNCTION get_rarity_multiplier IS 'Returns StatusXP multiplier based on rarity percentage: ≤1%=3.0, 1-5%=2.25, 5-10%=1.75, 10-25%=1.25, >25%=1.0';
COMMENT ON FUNCTION get_achievement_statusxp IS 'Calculates StatusXP for an achievement (base 100 × rarity multiplier). Excludes PS Platinums.';
COMMENT ON VIEW user_statusxp_scores IS 'Individual achievement StatusXP scores for each user';
COMMENT ON VIEW user_statusxp_totals IS 'Total StatusXP per platform per user, with base game vs DLC breakdown';
COMMENT ON VIEW user_statusxp_summary IS 'Overall StatusXP summary across all platforms per user';
