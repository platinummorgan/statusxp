-- Check the old table structure
SELECT COUNT(*) as platinum_count_old_table
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.type = 'platinum';

-- If that doesn't work, try this
SELECT COUNT(*) as platinum_count_direct
FROM user_trophies ut
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND ut.trophy_type = 'platinum';
