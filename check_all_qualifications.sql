-- Comprehensive achievement qualification check
-- User ID: 84b60ad6-cb2c-484f-8953-bf814551fd7a

-- 1. VOLUME ACHIEVEMENTS
SELECT 'VOLUME ACHIEVEMENTS' as category;

SELECT 
  'Total Achievements' as metric,
  (SELECT COUNT(*) FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') +
  (SELECT COUNT(*) FROM user_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') as count,
  CASE 
    WHEN ((SELECT COUNT(*) FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') +
          (SELECT COUNT(*) FROM user_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a')) >= 2500 THEN '✅ no_life_great_life'
    WHEN ((SELECT COUNT(*) FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') +
          (SELECT COUNT(*) FROM user_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a')) >= 1000 THEN '✅ achievement_engine'
    WHEN ((SELECT COUNT(*) FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') +
          (SELECT COUNT(*) FROM user_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a')) >= 500 THEN '✅ xp_machine'
    WHEN ((SELECT COUNT(*) FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') +
          (SELECT COUNT(*) FROM user_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a')) >= 250 THEN '✅ on_the_grind'
    WHEN ((SELECT COUNT(*) FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') +
          (SELECT COUNT(*) FROM user_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a')) >= 50 THEN '✅ warming_up'
    ELSE '❌ Not enough trophies'
  END as qualifies_for;

SELECT 
  'Platinum Count' as metric,
  COUNT(*) as count,
  CASE 
    WHEN COUNT(*) >= 50 THEN '✅ legendary_finisher'
    WHEN COUNT(*) >= 25 THEN '✅ certified_platinum'
    WHEN COUNT(*) >= 10 THEN '✅ double_digits'
    ELSE '❌ Not enough platinums'
  END as qualifies_for
FROM user_games 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' 
  AND has_platinum = true;

-- 2. PLATFORM ACHIEVEMENTS
SELECT '' as spacing;
SELECT 'PLATFORM ACHIEVEMENTS' as category;

SELECT 
  'PSN Games' as platform,
  COUNT(*) as game_count,
  CASE WHEN COUNT(*) > 0 THEN '✅ welcome_trophy_room' ELSE '❌' END as qualifies
FROM user_games 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' 
  AND platform_id = 1;

SELECT 
  'Xbox Games' as platform,
  COUNT(*) as game_count,
  CASE WHEN COUNT(*) > 0 THEN '✅ welcome_gamerscore' ELSE '❌' END as qualifies
FROM user_games 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' 
  AND platform_id = 2;

SELECT 
  'Steam Games' as platform,
  COUNT(*) as game_count,
  CASE WHEN COUNT(*) > 0 THEN '✅ welcome_pc_grind' ELSE '❌' END as qualifies
FROM user_games 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' 
  AND platform_id = 3;

SELECT 
  'Triforce Check' as check_name,
  (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 1) as psn_games,
  (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 2) as xbox_games,
  (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 3) as steam_games,
  CASE 
    WHEN (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 1) > 0
     AND (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 2) > 0
     AND (SELECT COUNT(*) FROM user_games WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a' AND platform_id = 3) > 0
    THEN '✅ triforce'
    ELSE '❌ Need all 3 platforms'
  END as qualifies;

-- 3. RARITY ACHIEVEMENTS
SELECT '' as spacing;
SELECT 'RARITY ACHIEVEMENTS' as category;

SELECT 
  'Trophies < 5%' as rarity_level,
  COUNT(*) as count,
  CASE 
    WHEN COUNT(*) >= 10 THEN '✅ mythic_hunter'
    WHEN COUNT(*) >= 5 THEN '✅ diamond_hands'
    WHEN COUNT(*) >= 1 THEN '✅ rare_air'
    ELSE '❌ None'
  END as qualifies_for
FROM trophies t
JOIN user_trophies ut ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.rarity_global < 5.0
  AND t.rarity_global IS NOT NULL;

SELECT 
  'Trophies < 2%' as rarity_level,
  COUNT(*) as count,
  CASE WHEN COUNT(*) >= 1 THEN '✅ baller' ELSE '❌' END as qualifies_for
FROM trophies t
JOIN user_trophies ut ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.rarity_global < 2.0
  AND t.rarity_global IS NOT NULL;

SELECT 
  'Trophies < 1%' as rarity_level,
  COUNT(*) as count,
  CASE WHEN COUNT(*) >= 1 THEN '✅ one_percenter' ELSE '❌' END as qualifies_for
FROM trophies t
JOIN user_trophies ut ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.rarity_global < 1.0
  AND t.rarity_global IS NOT NULL;

-- 4. META ACHIEVEMENTS
SELECT '' as spacing;
SELECT 'META ACHIEVEMENTS' as category;

SELECT 
  'All Platforms Synced' as check_name,
  CASE 
    WHEN last_psn_sync_at IS NOT NULL THEN 'PSN ✅' 
    ELSE 'PSN ❌' 
  END as psn_status,
  CASE 
    WHEN last_xbox_sync_at IS NOT NULL THEN 'Xbox ✅' 
    ELSE 'Xbox ❌' 
  END as xbox_status,
  CASE 
    WHEN last_steam_sync_at IS NOT NULL THEN 'Steam ✅' 
    ELSE 'Steam ❌' 
  END as steam_status,
  CASE 
    WHEN last_psn_sync_at IS NOT NULL 
     AND last_xbox_sync_at IS NOT NULL 
     AND last_steam_sync_at IS NOT NULL 
    THEN '✅ systems_online' 
    ELSE '❌' 
  END as qualifies
FROM profiles
WHERE id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

SELECT 
  'Total Trophies for rank_up_irl' as check_name,
  (SELECT COUNT(*) FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') +
  (SELECT COUNT(*) FROM user_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') as total_count,
  CASE 
    WHEN ((SELECT COUNT(*) FROM user_trophies WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a') +
          (SELECT COUNT(*) FROM user_achievements WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a')) >= 10000 
    THEN '✅ rank_up_irl' 
    ELSE '❌ Need 10,000+' 
  END as qualifies;

-- 5. CURRENTLY UNLOCKED ACHIEVEMENTS
SELECT '' as spacing;
SELECT 'CURRENTLY UNLOCKED ACHIEVEMENTS' as category;

SELECT 
  achievement_id,
  unlocked_at
FROM user_meta_achievements
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY unlocked_at DESC;
