-- Check if PSN achievement IDs exist
SELECT id 
FROM meta_achievements 
WHERE id IN ('psn_10_trophies', 'psn_50_trophies', 'psn_100_trophies', 'psn_25_bronze', 'psn_10_silver')
ORDER BY id;
