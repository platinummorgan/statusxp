-- Insert the 21 missing meta achievements that the code references

INSERT INTO meta_achievements (id, category, default_title, description, icon_emoji, sort_order, required_platforms) VALUES
('rare_air', 'rarity', 'Rare Air', 'Earn trophies with ultra-rare rarity', '💎', 10000, ARRAY['psn', 'xbox', 'steam']),
('baller', 'rarity', 'Baller', 'Earn high rarity achievements', '🏀', 10001, ARRAY['psn', 'xbox', 'steam']),
('one_percenter', 'rarity', 'One Percenter', 'Earn achievements with <1% rarity', '👑', 10002, ARRAY['psn', 'xbox', 'steam']),
('diamond_hands', 'rarity', 'Diamond Hands', 'Earn extremely rare achievements', '💎', 10003, ARRAY['psn', 'xbox', 'steam']),
('mythic_hunter', 'rarity', 'Mythic Hunter', 'Earn mythic rarity achievements', '🦄', 10004, ARRAY['psn', 'xbox', 'steam']),
('elite_finish', 'completion', 'Elite Finish', 'Complete games with high completion rate', '🏁', 10005, ARRAY['psn', 'xbox', 'steam']),
('sweat_lord', 'dedication', 'Sweat Lord', 'Play games with intense dedication', '💪', 10006, ARRAY['psn', 'xbox', 'steam']),
('never_casual', 'dedication', 'Never Casual', 'Maintain consistent high engagement', '🔥', 10007, ARRAY['psn', 'xbox', 'steam']),
('fresh_flex', 'recent', 'Fresh Flex', 'Unlock recent achievements', '✨', 10008, ARRAY['psn', 'xbox', 'steam']),
('warming_up', 'progress', 'Warming Up', 'Start building your collection', '🌱', 10009, ARRAY['psn', 'xbox', 'steam']),
('on_the_grind', 'progress', 'On The Grind', 'Make steady progress', '⚙️', 10010, ARRAY['psn', 'xbox', 'steam']),
('xp_machine', 'progress', 'XP Machine', 'Earn significant StatusXP', '🤖', 10011, ARRAY['psn', 'xbox', 'steam']),
('achievement_engine', 'progress', 'Achievement Engine', 'Unlock many achievements', '🚀', 10012, ARRAY['psn', 'xbox', 'steam']),
('no_life_great_life', 'dedication', 'No Life, Great Life', 'Extreme dedication to gaming', '🎮', 10013, ARRAY['psn', 'xbox', 'steam']),
('double_digits', 'completion', 'Double Digits', 'Complete 10+ games', '🔟', 10014, ARRAY['psn', 'xbox', 'steam']),
('certified_platinum', 'completion', 'Certified Platinum', 'Earn multiple platinum trophies', '💿', 10015, ARRAY['psn']),
('legendary_finisher', 'completion', 'Legendary Finisher', 'Complete legendary tier games', '👑', 10016, ARRAY['psn', 'xbox', 'steam']),
('spike_week', 'activity', 'Spike Week', 'Have a week of intense activity', '📈', 10017, ARRAY['psn', 'xbox', 'steam']),
('power_session', 'activity', 'Power Session', 'Have a gaming power session', '⚡', 10018, ARRAY['psn', 'xbox', 'steam']),
('welcome_trophy_room', 'milestone', 'Welcome to Trophy Room', 'First visit to trophy room', '🏠', 10019, ARRAY['psn']),
('welcome_gamerscore', 'milestone', 'Welcome Gamerscore', 'First gamerscore milestone', '🎯', 10020, ARRAY['xbox'])
ON CONFLICT (id) DO NOTHING;
