-- Fix corrupted metadata by copying trophy_type to psn_trophy_type
-- This restores the platinums without needing to re-sync

UPDATE achievements
SET metadata = metadata || jsonb_build_object('psn_trophy_type', metadata->>'trophy_type')
WHERE platform_id = 1
  AND metadata ? 'trophy_type'
  AND NOT metadata ? 'psn_trophy_type';

-- Verify the fix
SELECT COUNT(*) as platinums_restored
FROM user_achievements ua
INNER JOIN achievements a ON 
  a.platform_id = ua.platform_id 
  AND a.platform_game_id = ua.platform_game_id 
  AND a.platform_achievement_id = ua.platform_achievement_id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ua.platform_id = 1
  AND a.metadata->>'psn_trophy_type' = 'platinum';
