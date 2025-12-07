-- Count platinums in old table
SELECT COUNT(*) as platinum_count_old_table
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
WHERE ut.user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
  AND t.psn_trophy_type = 'platinum';

-- This should show 90 platinums (170 total - 80 already migrated = 90 remaining)
