-- Check if cross-platform achievement IDs from code exist in database
SELECT id 
FROM meta_achievements 
WHERE id IN (
  'cross_statusxp_500', 
  'cross_statusxp_3500', 
  'cross_statusxp_7500', 
  'cross_statusxp_25000',
  'cross_triple_threat',
  'cross_universal_gamer',
  'cross_platform_master',
  'cross_ecosystem_legend'
)
ORDER BY id;
