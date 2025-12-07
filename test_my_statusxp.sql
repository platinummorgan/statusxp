-- Test your StatusXP score!

-- 1. Your overall StatusXP summary
SELECT * FROM user_statusxp_summary
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- 2. StatusXP breakdown by platform
SELECT * FROM user_statusxp_totals
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY platform;

-- 3. Top 10 highest scoring achievements
SELECT 
  platform,
  game_name,
  achievement_name,
  rarity_global,
  statusxp,
  unlocked_at
FROM user_statusxp_scores
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY statusxp DESC, unlocked_at DESC
LIMIT 10;
