-- Link Ghost of Yōtei platinum achievement to DaHead22
-- This will make the leaderboard show 8 platinums

-- First, get the user ID
SELECT id, psn_online_id FROM profiles WHERE psn_online_id = 'DaHead22';

-- Insert the missing user_achievement record
INSERT INTO user_achievements (user_id, achievement_id, earned_at)
VALUES (
  '3c5206fb-6806-4f95-80d6-29ee7e974be9',  -- DaHead22's user_id
  176771,  -- Ghost of Yōtei platinum achievement
  NOW()  -- Use current timestamp since we don't have the exact date
)
ON CONFLICT (user_id, achievement_id) DO NOTHING;

-- Refresh the leaderboard cache to show the correct count
SELECT refresh_psn_leaderboard_cache();

-- Verify it worked
SELECT platinum_count FROM psn_leaderboard_cache 
WHERE user_id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';
