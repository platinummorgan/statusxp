-- Check the last synced game's trophy breakdown (from PSN summary)
SELECT 
    gt.name AS game_name,
    ug.bronze_trophies,
    ug.silver_trophies,
    ug.gold_trophies,
    ug.platinum_trophies,
    ug.updated_at
FROM user_games ug
JOIN game_titles gt ON ug.game_title_id = gt.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY ug.updated_at DESC
LIMIT 1;

-- Check individual trophies saved for that game
SELECT 
    gt.name AS game_name,
    t.name AS trophy_name,
    t.tier AS trophy_tier,
    t.description,
    ut.earned_at,
    t.sort_order
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
JOIN game_titles gt ON t.game_title_id = gt.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.game_title_id = (
      SELECT game_title_id 
      FROM user_games 
      WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
      ORDER BY updated_at DESC 
      LIMIT 1
  )
ORDER BY t.sort_order;

-- Count individual trophies by tier for comparison
SELECT 
    t.tier AS trophy_tier,
    COUNT(*) as count
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.game_title_id = (
      SELECT game_title_id 
      FROM user_games 
      WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
      ORDER BY updated_at DESC 
      LIMIT 1
  )
GROUP BY t.tier
ORDER BY t.tier;
