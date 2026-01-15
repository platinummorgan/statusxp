-- Check backfill progress in real-time
SELECT 
  COUNT(*) as total_psn,
  COUNT(proxied_icon_url) as proxied,
  COUNT(*) - COUNT(proxied_icon_url) as remaining,
  ROUND(COUNT(proxied_icon_url) * 100.0 / COUNT(*), 1) as percent_complete
FROM achievements
WHERE platform = 'psn'
  AND icon_url IS NOT NULL;

-- Started with: 20182 proxied (28.3%)
-- Target: ~71199 proxied (100%)
