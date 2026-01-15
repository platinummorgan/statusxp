-- Check icon status for achievements in your Flex Room
-- Replace 'your_user_id' with your actual user ID

-- First, get your user ID
SELECT id, username, display_name 
FROM profiles 
WHERE username = 'YOUR_USERNAME'; -- Replace with your username

-- Check your user achievements with icon status
SELECT 
  a.id,
  a.name,
  gt.name as game_name,
  a.platform,
  a.icon_url,
  a.proxied_icon_url,
  ua.earned_at,
  a.updated_at as achievement_updated_at
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE ua.user_id = 'YOUR_USER_ID' -- Replace with your user ID
  AND a.platform = 'psn'
  AND a.icon_url IS NOT NULL
ORDER BY ua.earned_at DESC
LIMIT 20;

-- Check specifically for achievements with NULL proxied_icon_url that you've earned
SELECT 
  COUNT(*) as total_earned_psn,
  COUNT(a.proxied_icon_url) as with_proxied_url,
  COUNT(*) - COUNT(a.proxied_icon_url) as missing_proxied_url
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = 'YOUR_USER_ID' -- Replace with your user ID
  AND a.platform = 'psn';
