-- Check icon proxy status for your recent sync

-- Get your user ID first
SELECT id, username, psn_id_email, last_psn_sync_at
FROM profiles
WHERE username = 'YOUR_USERNAME'; -- Replace with your username

-- Check how many of your PSN achievements have proxied icons
SELECT 
  COUNT(*) as total_your_achievements,
  COUNT(a.proxied_icon_url) as with_proxied_url,
  COUNT(*) - COUNT(a.proxied_icon_url) as missing_proxied_url,
  ROUND(COUNT(a.proxied_icon_url)::numeric / COUNT(*)::numeric * 100, 2) as percent_proxied
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
WHERE ua.user_id = 'YOUR_USER_ID' -- Replace with your user ID from query above
  AND a.platform = 'psn';

-- Sample of achievements missing proxied URLs
SELECT 
  a.name,
  gt.name as game_name,
  a.icon_url,
  a.proxied_icon_url,
  a.updated_at
FROM user_achievements ua
JOIN achievements a ON a.id = ua.achievement_id
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE ua.user_id = 'YOUR_USER_ID' -- Replace with your user ID
  AND a.platform = 'psn'
  AND a.proxied_icon_url IS NULL
LIMIT 10;
