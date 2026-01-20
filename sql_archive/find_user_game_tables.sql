-- Find tables related to user games/achievements
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name LIKE '%user%game%'
  OR table_name LIKE '%user%achievement%'
ORDER BY table_name;
