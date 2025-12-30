-- Check if ANY user has trophies
SELECT 
  p.username,
  COUNT(ut.trophy_id) as trophy_count
FROM profiles p
LEFT JOIN user_trophies ut ON ut.user_id = p.id
GROUP BY p.id, p.username
ORDER BY trophy_count DESC;
