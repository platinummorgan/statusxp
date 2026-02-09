-- Properly delete the duplicate Gmail account
-- Keep: ojjm11@outlook.com (main account)
-- Delete: oscarmargan20@gmail.com (duplicate)

BEGIN;

-- First verify both accounts exist and what data they have
SELECT 
  au.id,
  au.email,
  p.display_name,
  p.xbox_xuid,
  p.psn_online_id,
  p.steam_id,
  (SELECT COUNT(*) FROM activity_feed WHERE user_id = au.id) as activity_count
FROM auth.users au
LEFT JOIN profiles p ON p.id = au.id
WHERE au.email IN ('ojjm11@outlook.com', 'oscarmargan20@gmail.com');

-- Delete the Gmail account profile first
DELETE FROM profiles 
WHERE id = 'af65c7fb-d1ca-4cad-8f36-a94803ae7930';

-- Delete the Gmail auth user (this will cascade delete related data)
-- NOTE: You need to do this through Supabase Dashboard -> Authentication -> Users
-- because auth.users requires admin API, not SQL

-- For now, just show what would be deleted
SELECT 
  'Would delete user:' as action,
  id,
  email,
  created_at
FROM auth.users
WHERE id = 'af65c7fb-d1ca-4cad-8f36-a94803ae7930';

ROLLBACK; -- Don't commit yet, just showing the plan
