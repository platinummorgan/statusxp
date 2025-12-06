-- Check what trophy groups exist for the last synced game
SELECT 
    gt.name AS game_name,
    ptg.trophy_group_id,
    ptg.trophy_group_name,
    ptg.trophy_count_bronze,
    ptg.trophy_count_silver,
    ptg.trophy_count_gold,
    ptg.trophy_count_platinum
FROM psn_trophy_groups ptg
JOIN game_titles gt ON ptg.game_title_id = gt.id
JOIN user_games ug ON ug.game_title_id = gt.id
WHERE ug.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND gt.id = (
      SELECT game_title_id 
      FROM user_games 
      WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
      ORDER BY updated_at DESC 
      LIMIT 1
  )
ORDER BY ptg.trophy_group_id;
