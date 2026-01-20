-- Check if proxied_icon_url is being populated for PSN achievements

-- Check achievements with NULL proxied_icon_url (should be none after sync)
SELECT 
  a.id,
  a.name,
  gt.name as game_name,
  a.platform,
  a.icon_url,
  a.proxied_icon_url,
  a.updated_at
FROM achievements a
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE a.platform = 'psn'
  AND a.icon_url IS NOT NULL
  AND a.proxied_icon_url IS NULL
LIMIT 20;

-- Check sample of PSN achievements with proxied URLs
SELECT 
  a.id,
  a.name,
  gt.name as game_name,
  a.icon_url,
  a.proxied_icon_url,
  a.updated_at
FROM achievements a
JOIN game_titles gt ON gt.id = a.game_title_id
WHERE a.platform = 'psn'
  AND a.proxied_icon_url IS NOT NULL
ORDER BY a.updated_at DESC
LIMIT 10;

-- Count PSN achievements by proxied URL status
SELECT 
  COUNT(*) as total_psn_achievements,
  COUNT(proxied_icon_url) as with_proxied_url,
  COUNT(*) - COUNT(proxied_icon_url) as without_proxied_url
FROM achievements
WHERE platform = 'psn';
