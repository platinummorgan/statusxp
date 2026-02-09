-- Check per-platform StatusXP breakdown for your user
-- Replace 'YOUR_USER_ID' with your actual user ID

WITH statusxp_breakdown AS (
  SELECT 
    platform_id,
    COUNT(*) as game_count,
    SUM(statusxp_effective) as total_statusxp
  FROM calculate_statusxp_with_stacks('YOUR_USER_ID')
  GROUP BY platform_id
  ORDER BY platform_id
)
SELECT 
  platform_id,
  game_count,
  total_statusxp,
  CASE 
    WHEN platform_id IN (1, 2, 5, 9) THEN 'PSN'
    WHEN platform_id IN (10, 11, 12) THEN 'Xbox'
    WHEN platform_id = 4 THEN 'Steam'
    ELSE 'Other'
  END as platform_name
FROM statusxp_breakdown;

-- Also get totals by platform grouping
SELECT 
  CASE 
    WHEN platform_id IN (1, 2, 5, 9) THEN 'PSN'
    WHEN platform_id IN (10, 11, 12) THEN 'Xbox'
    WHEN platform_id = 4 THEN 'Steam'
    ELSE 'Other'
  END as platform_group,
  SUM(statusxp_effective) as total_statusxp
FROM calculate_statusxp_with_stacks('YOUR_USER_ID')
GROUP BY platform_group
ORDER BY total_statusxp DESC;
