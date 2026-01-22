-- Backfill Achievements for All Users
-- This script checks existing user data and awards achievements they've already earned

-- Create temporary table to hold user stats
CREATE TEMP TABLE user_stats AS
WITH user_trophy_counts AS (
  SELECT 
    ua.user_id,
    -- PSN trophy counts
    COUNT(CASE WHEN a.platform = 'psn' THEN 1 END) as psn_total,
    COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'bronze' THEN 1 END) as psn_bronze,
    COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'silver' THEN 1 END) as psn_silver,
    COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'gold' THEN 1 END) as psn_gold,
    COUNT(CASE WHEN a.platform = 'psn' AND a.psn_trophy_type = 'platinum' THEN 1 END) as psn_platinum,
    COUNT(CASE WHEN a.platform = 'psn' AND a.rarity_global < 10 THEN 1 END) as psn_rare,
    
    -- Xbox achievement counts
    COUNT(CASE WHEN a.platform = 'xbox' THEN 1 END) as xbox_total,
    COALESCE(SUM(CASE WHEN a.platform = 'xbox' THEN a.xbox_gamerscore ELSE 0 END), 0) as xbox_gamerscore,
    COUNT(CASE WHEN a.platform = 'xbox' AND a.rarity_global < 10 THEN 1 END) as xbox_rare,
    
    -- Steam achievement counts  
    COUNT(CASE WHEN a.platform = 'steam' THEN 1 END) as steam_total,
    COUNT(CASE WHEN a.platform = 'steam' AND a.rarity_global < 10 THEN 1 END) as steam_rare,
    
    -- Combined totals
    COUNT(*) as total_unlocks
  FROM user_achievements ua
  JOIN achievements a ON ua.achievement_id = a.id
  GROUP BY ua.user_id
),
user_completion_counts AS (
  SELECT
    ug.user_id,
    COUNT(CASE WHEN pl.code = 'XBOXONE' AND ug.completion_percent = 100 THEN 1 END) as xbox_complete,
    COUNT(CASE WHEN pl.code IN ('Steam') AND ug.completion_percent = 100 THEN 1 END) as steam_perfect
  FROM user_games ug
  JOIN platforms pl ON ug.platform_id = pl.id
  GROUP BY ug.user_id
),
user_profile_data AS (
  SELECT
    id as user_id
  FROM profiles
)
SELECT 
  p.user_id,
  COALESCE(tc.psn_total, 0) as psn_total,
  COALESCE(tc.psn_bronze, 0) as psn_bronze,
  COALESCE(tc.psn_silver, 0) as psn_silver,
  COALESCE(tc.psn_gold, 0) as psn_gold,
  COALESCE(tc.psn_platinum, 0) as psn_platinum,
  COALESCE(tc.psn_rare, 0) as psn_rare,
  COALESCE(tc.xbox_total, 0) as xbox_total,
  COALESCE(tc.xbox_gamerscore, 0) as xbox_gamerscore,
  COALESCE(tc.xbox_rare, 0) as xbox_rare,
  COALESCE(cc.xbox_complete, 0) as xbox_complete,
  COALESCE(tc.steam_total, 0) as steam_total,
  COALESCE(tc.steam_rare, 0) as steam_rare,
  COALESCE(cc.steam_perfect, 0) as steam_perfect,
  COALESCE(tc.total_unlocks, 0) as total_unlocks,
  -- Calculate StatusXP: bronze=15, silver=30, gold=90, platinum=300, xbox gamerscore/10
  (COALESCE(tc.psn_bronze, 0) * 15 + 
   COALESCE(tc.psn_silver, 0) * 30 + 
   COALESCE(tc.psn_gold, 0) * 90 + 
   COALESCE(tc.psn_platinum, 0) * 300 +
   COALESCE(tc.xbox_gamerscore, 0) / 10) as base_statusxp
FROM user_profile_data p
LEFT JOIN user_trophy_counts tc ON p.user_id = tc.user_id
LEFT JOIN user_completion_counts cc ON p.user_id = cc.user_id;

-- Now insert achievements based on stats
-- PSN Trophy Total Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('psn_first_trophy', 'psn_10_trophies', 'psn_50_trophies', 'psn_100_trophies', 
                'psn_250_trophies', 'psn_500_trophies', 'psn_1000_trophies', 'psn_2500_trophies',
                'psn_5000_trophies', 'psn_7500_trophies', 'psn_10000_trophies', 'psn_15000_trophies')
  AND (
    (ma.id = 'psn_first_trophy' AND us.psn_total >= 1) OR
    (ma.id = 'psn_10_trophies' AND us.psn_total >= 10) OR
    (ma.id = 'psn_50_trophies' AND us.psn_total >= 50) OR
    (ma.id = 'psn_100_trophies' AND us.psn_total >= 100) OR
    (ma.id = 'psn_250_trophies' AND us.psn_total >= 250) OR
    (ma.id = 'psn_500_trophies' AND us.psn_total >= 500) OR
    (ma.id = 'psn_1000_trophies' AND us.psn_total >= 1000) OR
    (ma.id = 'psn_2500_trophies' AND us.psn_total >= 2500) OR
    (ma.id = 'psn_5000_trophies' AND us.psn_total >= 5000) OR
    (ma.id = 'psn_7500_trophies' AND us.psn_total >= 7500) OR
    (ma.id = 'psn_10000_trophies' AND us.psn_total >= 10000) OR
    (ma.id = 'psn_15000_trophies' AND us.psn_total >= 15000)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- PSN Bronze Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('psn_25_bronze', 'psn_100_bronze', 'psn_500_bronze', 'psn_1000_bronze',
                'psn_2500_bronze', 'psn_5000_bronze', 'psn_7500_bronze', 'psn_10000_bronze')
  AND (
    (ma.id = 'psn_25_bronze' AND us.psn_bronze >= 25) OR
    (ma.id = 'psn_100_bronze' AND us.psn_bronze >= 100) OR
    (ma.id = 'psn_500_bronze' AND us.psn_bronze >= 500) OR
    (ma.id = 'psn_1000_bronze' AND us.psn_bronze >= 1000) OR
    (ma.id = 'psn_2500_bronze' AND us.psn_bronze >= 2500) OR
    (ma.id = 'psn_5000_bronze' AND us.psn_bronze >= 5000) OR
    (ma.id = 'psn_7500_bronze' AND us.psn_bronze >= 7500) OR
    (ma.id = 'psn_10000_bronze' AND us.psn_bronze >= 10000)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- PSN Silver Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('psn_25_silver', 'psn_100_silver', 'psn_500_silver', 'psn_1000_silver',
                'psn_2000_silver', 'psn_3000_silver')
  AND (
    (ma.id = 'psn_25_silver' AND us.psn_silver >= 25) OR
    (ma.id = 'psn_100_silver' AND us.psn_silver >= 100) OR
    (ma.id = 'psn_500_silver' AND us.psn_silver >= 500) OR
    (ma.id = 'psn_1000_silver' AND us.psn_silver >= 1000) OR
    (ma.id = 'psn_2000_silver' AND us.psn_silver >= 2000) OR
    (ma.id = 'psn_3000_silver' AND us.psn_silver >= 3000)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- PSN Gold Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('psn_10_gold', 'psn_50_gold', 'psn_250_gold', 'psn_500_gold',
                'psn_750_gold', 'psn_1000_gold')
  AND (
    (ma.id = 'psn_10_gold' AND us.psn_gold >= 10) OR
    (ma.id = 'psn_50_gold' AND us.psn_gold >= 50) OR
    (ma.id = 'psn_250_gold' AND us.psn_gold >= 250) OR
    (ma.id = 'psn_500_gold' AND us.psn_gold >= 500) OR
    (ma.id = 'psn_750_gold' AND us.psn_gold >= 750) OR
    (ma.id = 'psn_1000_gold' AND us.psn_gold >= 1000)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- PSN Platinum Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('psn_1_platinum', 'psn_10_platinum', 'psn_25_platinum', 'psn_50_platinum',
                'psn_100_platinum', 'psn_150_platinum', 'psn_200_platinum', 'psn_250_platinum')
  AND (
    (ma.id = 'psn_1_platinum' AND us.psn_platinum >= 1) OR
    (ma.id = 'psn_10_platinum' AND us.psn_platinum >= 10) OR
    (ma.id = 'psn_25_platinum' AND us.psn_platinum >= 25) OR
    (ma.id = 'psn_50_platinum' AND us.psn_platinum >= 50) OR
    (ma.id = 'psn_100_platinum' AND us.psn_platinum >= 100) OR
    (ma.id = 'psn_150_platinum' AND us.psn_platinum >= 150) OR
    (ma.id = 'psn_200_platinum' AND us.psn_platinum >= 200) OR
    (ma.id = 'psn_250_platinum' AND us.psn_platinum >= 250)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- PSN Rare Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('psn_1_rare', 'psn_10_rare', 'psn_25_rare', 'psn_50_rare',
                'psn_100_rare', 'psn_250_rare')
  AND (
    (ma.id = 'psn_1_rare' AND us.psn_rare >= 1) OR
    (ma.id = 'psn_10_rare' AND us.psn_rare >= 10) OR
    (ma.id = 'psn_25_rare' AND us.psn_rare >= 25) OR
    (ma.id = 'psn_50_rare' AND us.psn_rare >= 50) OR
    (ma.id = 'psn_100_rare' AND us.psn_rare >= 100) OR
    (ma.id = 'psn_250_rare' AND us.psn_rare >= 250)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Xbox Total Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('xbox_first_unlock', 'xbox_10_achievements', 'xbox_50_achievements', 'xbox_100_achievements',
                'xbox_250_achievements', 'xbox_500_achievements', 'xbox_1000_achievements', 'xbox_2500_achievements',
                'xbox_5000_achievements', 'xbox_7500_achievements', 'xbox_10000_achievements', 'xbox_15000_achievements')
  AND (
    (ma.id = 'xbox_first_unlock' AND us.xbox_total >= 1) OR
    (ma.id = 'xbox_10_achievements' AND us.xbox_total >= 10) OR
    (ma.id = 'xbox_50_achievements' AND us.xbox_total >= 50) OR
    (ma.id = 'xbox_100_achievements' AND us.xbox_total >= 100) OR
    (ma.id = 'xbox_250_achievements' AND us.xbox_total >= 250) OR
    (ma.id = 'xbox_500_achievements' AND us.xbox_total >= 500) OR
    (ma.id = 'xbox_1000_achievements' AND us.xbox_total >= 1000) OR
    (ma.id = 'xbox_2500_achievements' AND us.xbox_total >= 2500) OR
    (ma.id = 'xbox_5000_achievements' AND us.xbox_total >= 5000) OR
    (ma.id = 'xbox_7500_achievements' AND us.xbox_total >= 7500) OR
    (ma.id = 'xbox_10000_achievements' AND us.xbox_total >= 10000) OR
    (ma.id = 'xbox_15000_achievements' AND us.xbox_total >= 15000)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Xbox Gamerscore Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('xbox_1000_gs', 'xbox_5000_gs', 'xbox_10000_gs', 'xbox_25000_gs', 'xbox_50000_gs',
                'xbox_75000_gs', 'xbox_100000_gs', 'xbox_150000_gs', 'xbox_200000_gs', 'xbox_250000_gs', 'xbox_300000_gs')
  AND (
    (ma.id = 'xbox_1000_gs' AND us.xbox_gamerscore >= 1000) OR
    (ma.id = 'xbox_5000_gs' AND us.xbox_gamerscore >= 5000) OR
    (ma.id = 'xbox_10000_gs' AND us.xbox_gamerscore >= 10000) OR
    (ma.id = 'xbox_25000_gs' AND us.xbox_gamerscore >= 25000) OR
    (ma.id = 'xbox_50000_gs' AND us.xbox_gamerscore >= 50000) OR
    (ma.id = 'xbox_75000_gs' AND us.xbox_gamerscore >= 75000) OR
    (ma.id = 'xbox_100000_gs' AND us.xbox_gamerscore >= 100000) OR
    (ma.id = 'xbox_150000_gs' AND us.xbox_gamerscore >= 150000) OR
    (ma.id = 'xbox_200000_gs' AND us.xbox_gamerscore >= 200000) OR
    (ma.id = 'xbox_250000_gs' AND us.xbox_gamerscore >= 250000) OR
    (ma.id = 'xbox_300000_gs' AND us.xbox_gamerscore >= 300000)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Xbox Completion Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('xbox_1_complete', 'xbox_10_complete', 'xbox_25_complete', 
                'xbox_50_complete', 'xbox_100_complete', 'xbox_150_complete')
  AND (
    (ma.id = 'xbox_1_complete' AND us.xbox_complete >= 1) OR
    (ma.id = 'xbox_10_complete' AND us.xbox_complete >= 10) OR
    (ma.id = 'xbox_25_complete' AND us.xbox_complete >= 25) OR
    (ma.id = 'xbox_50_complete' AND us.xbox_complete >= 50) OR
    (ma.id = 'xbox_100_complete' AND us.xbox_complete >= 100) OR
    (ma.id = 'xbox_150_complete' AND us.xbox_complete >= 150)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Xbox Rare Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('xbox_1_rare', 'xbox_10_rare', 'xbox_25_rare', 'xbox_50_rare',
                'xbox_100_rare', 'xbox_250_rare')
  AND (
    (ma.id = 'xbox_1_rare' AND us.xbox_rare >= 1) OR
    (ma.id = 'xbox_10_rare' AND us.xbox_rare >= 10) OR
    (ma.id = 'xbox_25_rare' AND us.xbox_rare >= 25) OR
    (ma.id = 'xbox_50_rare' AND us.xbox_rare >= 50) OR
    (ma.id = 'xbox_100_rare' AND us.xbox_rare >= 100) OR
    (ma.id = 'xbox_250_rare' AND us.xbox_rare >= 250)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Steam Total Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('steam_first_unlock', 'steam_10_achievements', 'steam_50_achievements', 'steam_100_achievements',
                'steam_250_achievements', 'steam_500_achievements', 'steam_1000_achievements', 'steam_2500_achievements',
                'steam_5000_achievements', 'steam_7500_achievements', 'steam_10000_achievements', 'steam_15000_achievements')
  AND (
    (ma.id = 'steam_first_unlock' AND us.steam_total >= 1) OR
    (ma.id = 'steam_10_achievements' AND us.steam_total >= 10) OR
    (ma.id = 'steam_50_achievements' AND us.steam_total >= 50) OR
    (ma.id = 'steam_100_achievements' AND us.steam_total >= 100) OR
    (ma.id = 'steam_250_achievements' AND us.steam_total >= 250) OR
    (ma.id = 'steam_500_achievements' AND us.steam_total >= 500) OR
    (ma.id = 'steam_1000_achievements' AND us.steam_total >= 1000) OR
    (ma.id = 'steam_2500_achievements' AND us.steam_total >= 2500) OR
    (ma.id = 'steam_5000_achievements' AND us.steam_total >= 5000) OR
    (ma.id = 'steam_7500_achievements' AND us.steam_total >= 7500) OR
    (ma.id = 'steam_10000_achievements' AND us.steam_total >= 10000) OR
    (ma.id = 'steam_15000_achievements' AND us.steam_total >= 15000)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Steam Perfect Games
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('steam_1_perfect', 'steam_10_perfect', 'steam_25_perfect',
                'steam_50_perfect', 'steam_100_perfect', 'steam_150_perfect')
  AND (
    (ma.id = 'steam_1_perfect' AND us.steam_perfect >= 1) OR
    (ma.id = 'steam_10_perfect' AND us.steam_perfect >= 10) OR
    (ma.id = 'steam_25_perfect' AND us.steam_perfect >= 25) OR
    (ma.id = 'steam_50_perfect' AND us.steam_perfect >= 50) OR
    (ma.id = 'steam_100_perfect' AND us.steam_perfect >= 100) OR
    (ma.id = 'steam_150_perfect' AND us.steam_perfect >= 150)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Steam Rare Achievements
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('steam_1_rare', 'steam_10_rare', 'steam_25_rare', 'steam_50_rare',
                'steam_100_rare', 'steam_250_rare')
  AND (
    (ma.id = 'steam_1_rare' AND us.steam_rare >= 1) OR
    (ma.id = 'steam_10_rare' AND us.steam_rare >= 10) OR
    (ma.id = 'steam_25_rare' AND us.steam_rare >= 25) OR
    (ma.id = 'steam_50_rare' AND us.steam_rare >= 50) OR
    (ma.id = 'steam_100_rare' AND us.steam_rare >= 100) OR
    (ma.id = 'steam_250_rare' AND us.steam_rare >= 250)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Cross-Platform StatusXP Achievements  
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('cross_statusxp_500', 'cross_statusxp_1500', 'cross_statusxp_3500', 
                'cross_statusxp_7500', 'cross_statusxp_15000', 'cross_statusxp_20000', 'cross_statusxp_25000')
  AND us.psn_total > 0 AND us.xbox_total > 0 AND us.steam_total > 0 -- Must have all 3 platforms
  AND (
    (ma.id = 'cross_statusxp_500' AND us.base_statusxp >= 500) OR
    (ma.id = 'cross_statusxp_1500' AND us.base_statusxp >= 1500) OR
    (ma.id = 'cross_statusxp_3500' AND us.base_statusxp >= 3500) OR
    (ma.id = 'cross_statusxp_7500' AND us.base_statusxp >= 7500) OR
    (ma.id = 'cross_statusxp_15000' AND us.base_statusxp >= 15000) OR
    (ma.id = 'cross_statusxp_20000' AND us.base_statusxp >= 20000) OR
    (ma.id = 'cross_statusxp_25000' AND us.base_statusxp >= 25000)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Cross-Platform Multi-Platform Mastery
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('cross_triple_threat', 'cross_universal_gamer', 'cross_platform_master', 'cross_ecosystem_legend')
  AND us.psn_total > 0 AND us.xbox_total > 0 AND us.steam_total > 0 -- Must have all 3 platforms
  AND (
    (ma.id = 'cross_triple_threat' AND us.psn_total >= 100 AND us.xbox_total >= 100 AND us.steam_total >= 100) OR
    (ma.id = 'cross_universal_gamer' AND us.psn_total >= 500 AND us.xbox_total >= 500 AND us.steam_total >= 500) OR
    (ma.id = 'cross_platform_master' AND us.psn_total >= 1000 AND us.xbox_total >= 1000 AND us.steam_total >= 1000) OR
    (ma.id = 'cross_ecosystem_legend' AND us.psn_total >= 2500 AND us.xbox_total >= 2500 AND us.steam_total >= 2500)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Cross-Platform Combined Unlocks
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('cross_1000_unlocks', 'cross_2500_unlocks', 'cross_5000_unlocks',
                'cross_10000_unlocks', 'cross_15000_unlocks')
  AND us.psn_total > 0 AND us.xbox_total > 0 AND us.steam_total > 0 -- Must have all 3 platforms
  AND (
    (ma.id = 'cross_1000_unlocks' AND us.total_unlocks >= 1000) OR
    (ma.id = 'cross_2500_unlocks' AND us.total_unlocks >= 2500) OR
    (ma.id = 'cross_5000_unlocks' AND us.total_unlocks >= 5000) OR
    (ma.id = 'cross_10000_unlocks' AND us.total_unlocks >= 10000) OR
    (ma.id = 'cross_15000_unlocks' AND us.total_unlocks >= 15000)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Cross-Platform Rare Hunter
INSERT INTO user_meta_achievements (user_id, achievement_id, unlocked_at)
SELECT DISTINCT us.user_id, ma.id, NOW()
FROM user_stats us
CROSS JOIN meta_achievements ma
WHERE ma.id IN ('cross_rare_10_each', 'cross_rare_25_each', 'cross_rare_50_each')
  AND us.psn_total > 0 AND us.xbox_total > 0 AND us.steam_total > 0 -- Must have all 3 platforms
  AND (
    (ma.id = 'cross_rare_10_each' AND us.psn_rare >= 10 AND us.xbox_rare >= 10 AND us.steam_rare >= 10) OR
    (ma.id = 'cross_rare_25_each' AND us.psn_rare >= 25 AND us.xbox_rare >= 25 AND us.steam_rare >= 25) OR
    (ma.id = 'cross_rare_50_each' AND us.psn_rare >= 50 AND us.xbox_rare >= 50 AND us.steam_rare >= 50)
  )
  AND NOT EXISTS (
    SELECT 1 FROM user_meta_achievements uma 
    WHERE uma.user_id = us.user_id AND uma.achievement_id = ma.id
  );

-- Summary: Show unlocked achievements per user
SELECT 
  p.username,
  COUNT(*) as achievements_unlocked
FROM user_meta_achievements uma
JOIN profiles p ON uma.user_id = p.id
WHERE uma.unlocked_at > NOW() - INTERVAL '1 minute'
GROUP BY p.username
ORDER BY achievements_unlocked DESC;
