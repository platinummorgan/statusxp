-- Clear PSN leaderboard history to test NEW badges
-- This will make all PSN users appear as "NEW" on the next leaderboard fetch

DELETE FROM leaderboard_history 
WHERE leaderboard_type = 'platinum';

-- Verify it's cleared
SELECT COUNT(*) as remaining_records 
FROM leaderboard_history 
WHERE leaderboard_type = 'platinum';
