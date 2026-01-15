-- Verify backfill completed
SELECT 
  COUNT(*) as total_psn_achievements,
  COUNT(proxied_icon_url) as with_proxied_url,
  COUNT(*) - COUNT(proxied_icon_url) as without_proxied_url,
  ROUND(COUNT(proxied_icon_url) * 100.0 / COUNT(*), 2) as percent_proxied
FROM achievements
WHERE platform = 'psn'
  AND icon_url IS NOT NULL;
