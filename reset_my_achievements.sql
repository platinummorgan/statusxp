-- IMPORTANT: Run create_meta_achievements_tables.sql migration first!
-- This script requires the user_meta_achievements table to exist.

-- Reset all achievements for testing
-- This will let the achievement checker re-evaluate and unlock all qualifying achievements

DELETE FROM user_meta_achievements 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Expected unlocks based on your stats (170 platinums, 5 platforms):
-- Volume: warming_up, on_the_grind, xp_machine, achievement_engine, double_digits, certified_platinum, legendary_finisher
-- Platform: welcome_trophy_room, welcome_gamerscore, welcome_pc_grind, triforce, cross_platform_conqueror
-- Meta: systems_online, interior_designer (if Flex Room filled), rank_up_irl (if 10K+ trophies)
-- Plus any Time/Streak/Rarity achievements based on your trophy earn patterns
