-- PROPER FIX: Use xbox_title_id for accurate grouping
-- Falls back to game_title_id for legacy data without xbox_title_id
CREATE OR REPLACE FUNCTION refresh_xbox_leaderboard_cache()
RETURNS void AS $$
BEGIN
  TRUNCATE xbox_leaderboard_cache;
  
  INSERT INTO xbox_leaderboard_cache (user_id, display_name, avatar_url, gamerscore, achievement_count, total_games, updated_at)
  SELECT 
    ug.user_id,
    p.xbox_gamertag as display_name,
    p.xbox_avatar_url as avatar_url,
    SUM(ug.xbox_current_gamerscore) as gamerscore,
    SUM(ug.xbox_achievements_earned) as achievement_count,
    -- Count unique games by xbox_title_id (or game_title_id if no xbox_title_id)
    COUNT(DISTINCT COALESCE(gt.xbox_title_id, ug.game_title_id::text)) as total_games,
    NOW() as updated_at
  FROM user_games ug
  INNER JOIN profiles p ON p.id = ug.user_id
  INNER JOIN platforms pl ON pl.id = ug.platform_id
  INNER JOIN game_titles gt ON gt.id = ug.game_title_id
  WHERE pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
    AND p.show_on_leaderboard = true
    AND p.xbox_xuid IS NOT NULL
    AND ug.xbox_current_gamerscore > 0
  GROUP BY ug.user_id, p.xbox_gamertag, p.xbox_avatar_url;
END;
$$ LANGUAGE plpgsql;

-- Refresh
SELECT refresh_xbox_leaderboard_cache();

-- Verify Gordon's results
SELECT display_name, gamerscore, total_games
FROM xbox_leaderboard_cache
WHERE display_name = 'XxlmThumperxX';

-- Show breakdown for Gordon to verify
SELECT 
  gt.name,
  gt.xbox_title_id,
  pl.code as platform,
  ug.xbox_current_gamerscore
FROM user_games ug
JOIN game_titles gt ON gt.id = ug.game_title_id
JOIN platforms pl ON pl.id = ug.platform_id
JOIN profiles p ON p.id = ug.user_id
WHERE p.xbox_gamertag = 'XxlmThumperxX'
  AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  AND ug.xbox_current_gamerscore > 0
ORDER BY gt.name, pl.code
LIMIT 50;
