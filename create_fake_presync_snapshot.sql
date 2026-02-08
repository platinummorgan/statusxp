-- Step 1: Check your current stats first
SELECT 
  total_statusxp,
  platinum_count,
  psn_gold_count,
  psn_silver_count,
  psn_bronze_count,
  synced_at
FROM user_stat_snapshots
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY synced_at DESC
LIMIT 1;

-- Step 2: Insert fake pre-sync snapshot with 8 fewer bronze trophies
-- Copy the values from above, then subtract 8 from psn_bronze_count
INSERT INTO user_stat_snapshots (
  user_id,
  total_statusxp,
  platinum_count,
  psn_gold_count,
  psn_silver_count,
  psn_bronze_count,
  gamerscore,
  steam_achievement_count,
  latest_game_title,
  latest_platform_id,
  synced_at
) 
SELECT 
  '84b60ad6-cb2c-484f-8953-bf814551fd7a',
  total_statusxp,
  platinum_count,
  psn_gold_count,
  psn_silver_count,
  psn_bronze_count - 8,  -- Subtract 8 bronze
  0,
  0,
  'Nexomon: Extinction',
  1,  -- PSN
  NOW()
FROM user_stat_snapshots
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY synced_at DESC
LIMIT 1;

-- Step 3: Verify the fake snapshot was created
SELECT 
  total_statusxp,
  psn_bronze_count,
  synced_at
FROM user_stat_snapshots
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY synced_at DESC
LIMIT 2;
