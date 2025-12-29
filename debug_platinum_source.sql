-- Debug: Where is the platinum count coming from?
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- Check user_stats table
SELECT 
    platinum_count,
    total_trophies,
    bronze_count,
    silver_count,
    gold_count
FROM user_stats
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check psn_user_trophy_profile
SELECT 
    psn_earned_platinum,
    psn_earned_gold,
    psn_earned_silver,
    psn_earned_bronze
FROM psn_user_trophy_profile
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check if ANY user_trophies exist for this user
SELECT COUNT(*) as total_user_trophies
FROM user_trophies
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check user_achievements (might be using achievements table instead)
SELECT COUNT(*) as total_user_achievements
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
    AND a.is_platinum = true;
