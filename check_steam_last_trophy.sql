-- Check Steam last trophy dates for Dex-Morgan

SELECT 
  gt.name as game,
  ug.earned_trophies,
  ug.total_trophies,
  ug.last_trophy_earned_at,
  ug.last_played_at
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
JOIN platforms p ON ug.platform_id = p.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND p.code = 'Steam'
ORDER BY ug.last_trophy_earned_at DESC NULLS LAST;
