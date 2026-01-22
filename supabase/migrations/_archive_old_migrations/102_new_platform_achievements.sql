-- New Platform-Specific Achievement System
-- Replace old achievements with organized platform-specific categories

-- Delete all existing meta achievements (will cascade to user_meta_achievements)
DELETE FROM meta_achievements;

-- ============================================================================
-- PSN (PLAYSTATION) ACHIEVEMENTS
-- ============================================================================

-- Trophy Total Milestones
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('psn_first_trophy', 'volume', 'First Trophy', 'Unlock your first PlayStation trophy', '🏆', 100, ARRAY['psn']),
('psn_10_trophies', 'volume', 'Getting Warm', 'Unlock 10 PlayStation trophies', '🔥', 101, ARRAY['psn']),
('psn_50_trophies', 'volume', 'Trophy Case', 'Unlock 50 PlayStation trophies', '📦', 102, ARRAY['psn']),
('psn_100_trophies', 'volume', 'Shelf Builder', 'Unlock 100 PlayStation trophies', '🏗️', 103, ARRAY['psn']),
('psn_250_trophies', 'volume', 'Vault Starter', 'Unlock 250 PlayStation trophies', '🚪', 104, ARRAY['psn']),
('psn_500_trophies', 'volume', 'Vault Keeper', 'Unlock 500 PlayStation trophies', '🔐', 105, ARRAY['psn']),
('psn_1000_trophies', 'volume', 'The Hoard', 'Unlock 1,000 PlayStation trophies', '💎', 106, ARRAY['psn']),
('psn_2500_trophies', 'volume', 'Trophy Vault', 'Unlock 2,500 PlayStation trophies', '🏛️', 107, ARRAY['psn']),
('psn_5000_trophies', 'volume', 'Trophy Master', 'Unlock 5,000 PlayStation trophies', '👑', 108, ARRAY['psn']),
('psn_7500_trophies', 'volume', 'Trophy Legend', 'Unlock 7,500 PlayStation trophies', '⭐', 109, ARRAY['psn']),
('psn_10000_trophies', 'volume', 'Trophy God', 'Unlock 10,000 PlayStation trophies', '⚡', 110, ARRAY['psn']),
('psn_15000_trophies', 'volume', 'Trophy Immortal', 'Unlock 15,000 PlayStation trophies', '☄️', 111, ARRAY['psn']);

-- Bronze Trophies
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('psn_25_bronze', 'volume', 'Bronze Beginner', 'Earn 25 bronze trophies', '🥉', 200, ARRAY['psn']),
('psn_100_bronze', 'volume', 'Bronze Collector', 'Earn 100 bronze trophies', '🥉', 201, ARRAY['psn']),
('psn_500_bronze', 'volume', 'Bronze Hunter', 'Earn 500 bronze trophies', '🥉', 202, ARRAY['psn']),
('psn_1000_bronze', 'volume', 'Bronze Master', 'Earn 1,000 bronze trophies', '🥉', 203, ARRAY['psn']),
('psn_2500_bronze', 'volume', 'Bronze Hoarder', 'Earn 2,500 bronze trophies', '🥉', 204, ARRAY['psn']),
('psn_5000_bronze', 'volume', 'Bronze Legend', 'Earn 5,000 bronze trophies', '🥉', 205, ARRAY['psn']),
('psn_7500_bronze', 'volume', 'Bronze God', 'Earn 7,500 bronze trophies', '🥉', 206, ARRAY['psn']),
('psn_10000_bronze', 'volume', 'Bronze Immortal', 'Earn 10,000 bronze trophies', '🥉', 207, ARRAY['psn']);

-- Silver Trophies
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('psn_25_silver', 'volume', 'Silver Spark', 'Earn 25 silver trophies', '🥈', 300, ARRAY['psn']),
('psn_100_silver', 'volume', 'Silver Collector', 'Earn 100 silver trophies', '🥈', 301, ARRAY['psn']),
('psn_500_silver', 'volume', 'Silver Hunter', 'Earn 500 silver trophies', '🥈', 302, ARRAY['psn']),
('psn_1000_silver', 'volume', 'Silver Master', 'Earn 1,000 silver trophies', '🥈', 303, ARRAY['psn']),
('psn_2000_silver', 'volume', 'Silver Legend', 'Earn 2,000 silver trophies', '🥈', 304, ARRAY['psn']),
('psn_3000_silver', 'volume', 'Silver God', 'Earn 3,000 silver trophies', '🥈', 305, ARRAY['psn']);

-- Gold Trophies
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('psn_10_gold', 'volume', 'Gold Spark', 'Earn 10 gold trophies', '🥇', 400, ARRAY['psn']),
('psn_50_gold', 'volume', 'Gold Collector', 'Earn 50 gold trophies', '🥇', 401, ARRAY['psn']),
('psn_250_gold', 'volume', 'Gold Hunter', 'Earn 250 gold trophies', '🥇', 402, ARRAY['psn']),
('psn_500_gold', 'volume', 'Gold Master', 'Earn 500 gold trophies', '🥇', 403, ARRAY['psn']),
('psn_750_gold', 'volume', 'Gold Legend', 'Earn 750 gold trophies', '🥇', 404, ARRAY['psn']),
('psn_1000_gold', 'volume', 'Gold God', 'Earn 1,000 gold trophies', '🥇', 405, ARRAY['psn']);

-- Platinum Trophies
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('psn_1_platinum', 'completion', 'Platinum Spark', 'Earn your first platinum trophy', '💿', 500, ARRAY['psn']),
('psn_10_platinum', 'completion', 'Platinum Collector', 'Earn 10 platinum trophies', '💿', 501, ARRAY['psn']),
('psn_25_platinum', 'completion', 'Platinum Hunter', 'Earn 25 platinum trophies', '💿', 502, ARRAY['psn']),
('psn_50_platinum', 'completion', 'Platinum Master', 'Earn 50 platinum trophies', '💿', 503, ARRAY['psn']),
('psn_100_platinum', 'completion', 'Platinum Legend', 'Earn 100 platinum trophies', '💿', 504, ARRAY['psn']),
('psn_150_platinum', 'completion', 'Platinum God', 'Earn 150 platinum trophies', '💿', 505, ARRAY['psn']),
('psn_200_platinum', 'completion', 'Platinum Immortal', 'Earn 200 platinum trophies', '💿', 506, ARRAY['psn']),
('psn_250_platinum', 'completion', 'Platinum Deity', 'Earn 250 platinum trophies', '💿', 507, ARRAY['psn']);

-- Rare Trophy Hunter
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('psn_1_rare', 'rarity', 'Rare Find', 'Earn 1 rare trophy (<10% rarity)', '💎', 600, ARRAY['psn']),
('psn_10_rare', 'rarity', 'Rare Collector', 'Earn 10 rare trophies', '💎', 601, ARRAY['psn']),
('psn_25_rare', 'rarity', 'Rare Hunter', 'Earn 25 rare trophies', '💎', 602, ARRAY['psn']),
('psn_50_rare', 'rarity', 'Rare Master', 'Earn 50 rare trophies', '💎', 603, ARRAY['psn']),
('psn_100_rare', 'rarity', 'Rare Legend', 'Earn 100 rare trophies', '💎', 604, ARRAY['psn']),
('psn_250_rare', 'rarity', 'Rare God', 'Earn 250 rare trophies', '💎', 605, ARRAY['psn']);

-- ============================================================================
-- XBOX ACHIEVEMENTS
-- ============================================================================

-- Achievement Total Milestones
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('xbox_first_unlock', 'volume', 'First Unlock', 'Unlock your first Xbox achievement', '🎮', 1100, ARRAY['xbox']),
('xbox_10_achievements', 'volume', 'Getting Started', 'Unlock 10 Xbox achievements', '🔥', 1101, ARRAY['xbox']),
('xbox_50_achievements', 'volume', 'Achievement Case', 'Unlock 50 Xbox achievements', '📦', 1102, ARRAY['xbox']),
('xbox_100_achievements', 'volume', 'Shelf Builder', 'Unlock 100 Xbox achievements', '🏗️', 1103, ARRAY['xbox']),
('xbox_250_achievements', 'volume', 'Vault Starter', 'Unlock 250 Xbox achievements', '🚪', 1104, ARRAY['xbox']),
('xbox_500_achievements', 'volume', 'Vault Keeper', 'Unlock 500 Xbox achievements', '🔐', 1105, ARRAY['xbox']),
('xbox_1000_achievements', 'volume', 'The Hoard', 'Unlock 1,000 Xbox achievements', '💎', 1106, ARRAY['xbox']),
('xbox_2500_achievements', 'volume', 'Achievement Vault', 'Unlock 2,500 Xbox achievements', '🏛️', 1107, ARRAY['xbox']),
('xbox_5000_achievements', 'volume', 'Achievement Master', 'Unlock 5,000 Xbox achievements', '👑', 1108, ARRAY['xbox']),
('xbox_7500_achievements', 'volume', 'Achievement Legend', 'Unlock 7,500 Xbox achievements', '⭐', 1109, ARRAY['xbox']),
('xbox_10000_achievements', 'volume', 'Achievement God', 'Unlock 10,000 Xbox achievements', '⚡', 1110, ARRAY['xbox']),
('xbox_15000_achievements', 'volume', 'Achievement Immortal', 'Unlock 15,000 Xbox achievements', '☄️', 1111, ARRAY['xbox']);

-- Gamerscore Milestones
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('xbox_1000_gs', 'volume', 'Score Starter', 'Reach 1,000 Gamerscore', '🏅', 1200, ARRAY['xbox']),
('xbox_5000_gs', 'volume', 'Score Builder', 'Reach 5,000 Gamerscore', '🏅', 1201, ARRAY['xbox']),
('xbox_10000_gs', 'volume', 'Score Collector', 'Reach 10,000 Gamerscore', '🏅', 1202, ARRAY['xbox']),
('xbox_25000_gs', 'volume', 'Score Hunter', 'Reach 25,000 Gamerscore', '🏅', 1203, ARRAY['xbox']),
('xbox_50000_gs', 'volume', 'Score Master', 'Reach 50,000 Gamerscore', '🏅', 1204, ARRAY['xbox']),
('xbox_75000_gs', 'volume', 'Score Legend', 'Reach 75,000 Gamerscore', '🏅', 1205, ARRAY['xbox']),
('xbox_100000_gs', 'volume', 'Score God', 'Reach 100,000 Gamerscore', '🏅', 1206, ARRAY['xbox']),
('xbox_150000_gs', 'volume', 'Score Titan', 'Reach 150,000 Gamerscore', '🏅', 1207, ARRAY['xbox']),
('xbox_200000_gs', 'volume', 'Score Immortal', 'Reach 200,000 Gamerscore', '🏅', 1208, ARRAY['xbox']),
('xbox_250000_gs', 'volume', 'Score Deity', 'Reach 250,000 Gamerscore', '🏅', 1209, ARRAY['xbox']),
('xbox_300000_gs', 'volume', 'Score Eternal', 'Reach 300,000 Gamerscore', '🏅', 1210, ARRAY['xbox']);

-- Game Completion
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('xbox_1_complete', 'completion', 'First 100%', 'Complete 1 Xbox game (100%)', '✅', 1300, ARRAY['xbox']),
('xbox_10_complete', 'completion', 'Completionist', 'Complete 10 Xbox games', '✅', 1301, ARRAY['xbox']),
('xbox_25_complete', 'completion', 'Completion Hunter', 'Complete 25 Xbox games', '✅', 1302, ARRAY['xbox']),
('xbox_50_complete', 'completion', 'Completion Master', 'Complete 50 Xbox games', '✅', 1303, ARRAY['xbox']),
('xbox_100_complete', 'completion', 'Completion Legend', 'Complete 100 Xbox games', '✅', 1304, ARRAY['xbox']),
('xbox_150_complete', 'completion', 'Completion God', 'Complete 150 Xbox games', '✅', 1305, ARRAY['xbox']);

-- Rare Achievement Hunter
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('xbox_1_rare', 'rarity', 'Rare Find', 'Earn 1 rare Xbox achievement (<10% rarity)', '💎', 1400, ARRAY['xbox']),
('xbox_10_rare', 'rarity', 'Rare Collector', 'Earn 10 rare Xbox achievements', '💎', 1401, ARRAY['xbox']),
('xbox_25_rare', 'rarity', 'Rare Hunter', 'Earn 25 rare Xbox achievements', '💎', 1402, ARRAY['xbox']),
('xbox_50_rare', 'rarity', 'Rare Master', 'Earn 50 rare Xbox achievements', '💎', 1403, ARRAY['xbox']),
('xbox_100_rare', 'rarity', 'Rare Legend', 'Earn 100 rare Xbox achievements', '💎', 1404, ARRAY['xbox']),
('xbox_250_rare', 'rarity', 'Rare God', 'Earn 250 rare Xbox achievements', '💎', 1405, ARRAY['xbox']);

-- ============================================================================
-- STEAM ACHIEVEMENTS
-- ============================================================================

-- Achievement Total Milestones
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('steam_first_unlock', 'volume', 'First Unlock', 'Unlock your first Steam achievement', '⚙️', 2100, ARRAY['steam']),
('steam_10_achievements', 'volume', 'Getting Started', 'Unlock 10 Steam achievements', '🔥', 2101, ARRAY['steam']),
('steam_50_achievements', 'volume', 'Achievement Case', 'Unlock 50 Steam achievements', '📦', 2102, ARRAY['steam']),
('steam_100_achievements', 'volume', 'Shelf Builder', 'Unlock 100 Steam achievements', '🏗️', 2103, ARRAY['steam']),
('steam_250_achievements', 'volume', 'Vault Starter', 'Unlock 250 Steam achievements', '🚪', 2104, ARRAY['steam']),
('steam_500_achievements', 'volume', 'Vault Keeper', 'Unlock 500 Steam achievements', '🔐', 2105, ARRAY['steam']),
('steam_1000_achievements', 'volume', 'The Hoard', 'Unlock 1,000 Steam achievements', '💎', 2106, ARRAY['steam']),
('steam_2500_achievements', 'volume', 'Achievement Vault', 'Unlock 2,500 Steam achievements', '🏛️', 2107, ARRAY['steam']),
('steam_5000_achievements', 'volume', 'Achievement Master', 'Unlock 5,000 Steam achievements', '👑', 2108, ARRAY['steam']),
('steam_7500_achievements', 'volume', 'Achievement Legend', 'Unlock 7,500 Steam achievements', '⭐', 2109, ARRAY['steam']),
('steam_10000_achievements', 'volume', 'Achievement God', 'Unlock 10,000 Steam achievements', '⚡', 2110, ARRAY['steam']),
('steam_15000_achievements', 'volume', 'Achievement Immortal', 'Unlock 15,000 Steam achievements', '☄️', 2111, ARRAY['steam']);

-- Perfect Games
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('steam_1_perfect', 'completion', 'First Perfect', 'Complete 1 Steam game (all achievements)', '✨', 2200, ARRAY['steam']),
('steam_10_perfect', 'completion', 'Perfectionist', 'Complete 10 Steam games', '✨', 2201, ARRAY['steam']),
('steam_25_perfect', 'completion', 'Perfect Hunter', 'Complete 25 Steam games', '✨', 2202, ARRAY['steam']),
('steam_50_perfect', 'completion', 'Perfect Master', 'Complete 50 Steam games', '✨', 2203, ARRAY['steam']),
('steam_100_perfect', 'completion', 'Perfect Legend', 'Complete 100 Steam games', '✨', 2204, ARRAY['steam']),
('steam_150_perfect', 'completion', 'Perfect God', 'Complete 150 Steam games', '✨', 2205, ARRAY['steam']);

-- Rare Achievement Hunter
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('steam_1_rare', 'rarity', 'Rare Find', 'Earn 1 rare Steam achievement (<10% rarity)', '💎', 2300, ARRAY['steam']),
('steam_10_rare', 'rarity', 'Rare Collector', 'Earn 10 rare Steam achievements', '💎', 2301, ARRAY['steam']),
('steam_25_rare', 'rarity', 'Rare Hunter', 'Earn 25 rare Steam achievements', '💎', 2302, ARRAY['steam']),
('steam_50_rare', 'rarity', 'Rare Master', 'Earn 50 rare Steam achievements', '💎', 2303, ARRAY['steam']),
('steam_100_rare', 'rarity', 'Rare Legend', 'Earn 100 rare Steam achievements', '💎', 2304, ARRAY['steam']),
('steam_250_rare', 'rarity', 'Rare God', 'Earn 250 rare Steam achievements', '💎', 2305, ARRAY['steam']);

-- ============================================================================
-- CROSS-PLATFORM ACHIEVEMENTS (Requires all 3 platforms)
-- ============================================================================

-- StatusXP Milestones
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('cross_statusxp_500', 'volume', 'StatusXP', 'Reach 500 StatusXP total', '⚡', 3000, ARRAY['psn', 'xbox', 'steam']),
('cross_statusxp_1500', 'volume', 'StatusXP II', 'Reach 1,500 StatusXP total', '⚡', 3001, ARRAY['psn', 'xbox', 'steam']),
('cross_statusxp_3500', 'volume', 'StatusXP III', 'Reach 3,500 StatusXP total', '⚡', 3002, ARRAY['psn', 'xbox', 'steam']),
('cross_statusxp_7500', 'volume', 'StatusXP IV', 'Reach 7,500 StatusXP total', '⚡', 3003, ARRAY['psn', 'xbox', 'steam']),
('cross_statusxp_15000', 'volume', 'StatusXP V', 'Reach 15,000 StatusXP total', '⚡', 3004, ARRAY['psn', 'xbox', 'steam']),
('cross_statusxp_20000', 'volume', 'StatusXP VI', 'Reach 20,000 StatusXP total', '⚡', 3005, ARRAY['psn', 'xbox', 'steam']),
('cross_statusxp_25000', 'volume', 'StatusXP VII', 'Reach 25,000 StatusXP total', '⚡', 3006, ARRAY['psn', 'xbox', 'steam']);

-- Multi-Platform Mastery
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('cross_platform_hopper', 'platform', 'Platform Hopper', 'Earn achievements on all 3 platforms in 1 day', '🎯', 3100, ARRAY['psn', 'xbox', 'steam']),
('cross_triple_threat', 'volume', 'Triple Threat', 'Earn 100+ achievements on each platform', '🎮', 3101, ARRAY['psn', 'xbox', 'steam']),
('cross_universal_gamer', 'volume', 'Universal Gamer', 'Earn 500+ achievements on each platform', '🌐', 3102, ARRAY['psn', 'xbox', 'steam']),
('cross_platform_master', 'volume', 'Platform Master', 'Earn 1,000+ achievements on each platform', '👑', 3103, ARRAY['psn', 'xbox', 'steam']),
('cross_ecosystem_legend', 'volume', 'Ecosystem Legend', 'Earn 2,500+ achievements on each platform', '⭐', 3104, ARRAY['psn', 'xbox', 'steam']);

-- Same Game, All Platforms
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('cross_double_dip', 'completion', 'Double Dip', 'Complete same game on 2 different platforms', '🔄', 3200, ARRAY['psn', 'xbox', 'steam']),
('cross_triple_play', 'completion', 'Triple Play', 'Complete same game on all 3 platforms', '🎲', 3201, ARRAY['psn', 'xbox', 'steam']),
('cross_triple_platinum', 'completion', 'Triple Platinum', 'Earn platinum/100% on same game across all 3 platforms', '💿', 3202, ARRAY['psn', 'xbox', 'steam']),
('cross_collection_complete', 'completion', 'Collection Completionist', 'Complete 5 games across all platforms', '📚', 3203, ARRAY['psn', 'xbox', 'steam']),
('cross_platform_complete', 'completion', 'Platform Completionist', 'Complete 10 games across all platforms', '🏆', 3204, ARRAY['psn', 'xbox', 'steam']);

-- Combined Unlocks
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('cross_1000_unlocks', 'volume', 'Multi-Platform Collector', 'Earn 1,000 total unlocks across all platforms', '🎁', 3300, ARRAY['psn', 'xbox', 'steam']),
('cross_2500_unlocks', 'volume', 'Multi-Platform Hunter', 'Earn 2,500 total unlocks across all platforms', '🎁', 3301, ARRAY['psn', 'xbox', 'steam']),
('cross_5000_unlocks', 'volume', 'Multi-Platform Master', 'Earn 5,000 total unlocks across all platforms', '🎁', 3302, ARRAY['psn', 'xbox', 'steam']),
('cross_10000_unlocks', 'volume', 'Multi-Platform Legend', 'Earn 10,000 total unlocks across all platforms', '🎁', 3303, ARRAY['psn', 'xbox', 'steam']),
('cross_15000_unlocks', 'volume', 'Multi-Platform God', 'Earn 15,000 total unlocks across all platforms', '🎁', 3304, ARRAY['psn', 'xbox', 'steam']);

-- Rare Hunter (Cross-Platform)
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('cross_rare_10_each', 'rarity', 'Rare Across Worlds', 'Earn 10 rare achievements (<10%) on each platform', '💎', 3400, ARRAY['psn', 'xbox', 'steam']),
('cross_rare_25_each', 'rarity', 'Triple Rare Hunter', 'Earn 25 rare achievements on each platform', '💎', 3401, ARRAY['psn', 'xbox', 'steam']),
('cross_rare_50_each', 'rarity', 'Universal Rare Master', 'Earn 50 rare achievements on each platform', '💎', 3402, ARRAY['psn', 'xbox', 'steam']);

-- Game Library
INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('cross_50_games', 'variety', 'Multi-Platform Library', 'Own 50+ games across all platforms', '📚', 3500, ARRAY['psn', 'xbox', 'steam']),
('cross_100_games', 'variety', 'Diverse Collection', 'Own 100+ games across all platforms', '📚', 3501, ARRAY['psn', 'xbox', 'steam']),
('cross_250_games', 'variety', 'Universal Collector', 'Own 250+ games across all platforms', '📚', 3502, ARRAY['psn', 'xbox', 'steam']);
