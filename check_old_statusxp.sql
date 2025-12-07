-- Check if there's an old StatusXP view or calculation
SELECT table_name, view_definition 
FROM information_schema.views 
WHERE table_schema = 'public' 
  AND table_name LIKE '%statusxp%';

-- Check what the original total was
SELECT * FROM user_statusxp_summary 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';

-- Check if there's a user_stats table with the old value
SELECT * FROM user_stats 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a';
