-- Check if achievements exist for the trophies we're trying to migrate
SELECT COUNT(*) as matching_achievements_exist
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
JOIN achievements a ON (
  a.game_title_id = t.game_title_id 
  AND a.platform = 'psn'
  AND a.platform_achievement_id = t.psn_trophy_id::text
)
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check how many trophies DON'T have matching achievements
SELECT COUNT(*) as trophies_without_achievements
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND NOT EXISTS (
    SELECT 1 FROM achievements a
    WHERE a.game_title_id = t.game_title_id 
      AND a.platform = 'psn'
      AND a.platform_achievement_id = t.psn_trophy_id::text
  );
