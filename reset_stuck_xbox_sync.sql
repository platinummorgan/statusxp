-- Reset stuck Xbox sync for a user
-- Run this in Supabase SQL Editor

-- First, find the stuck user (ojjm11 / xdoscbobbles)
SELECT 
  p.id, 
  p.username, 
  u.email,
  p.xbox_sync_status, 
  p.xbox_sync_progress,
  p.xbox_sync_error
FROM profiles p
LEFT JOIN auth.users u ON p.id = u.id
WHERE p.username ILIKE '%ojjm11%';

-- Once you have their ID, reset their sync status
UPDATE profiles 
SET 
  xbox_sync_status = 'idle',
  xbox_sync_progress = 0,
  xbox_sync_error = NULL
WHERE id = 'b23e206a-02d1-4920-b1ee-61ee44583518';

-- Verify the fix
SELECT 
  username, 
  xbox_sync_status, 
  xbox_sync_progress
FROM profiles 
WHERE id = 'b23e206a-02d1-4920-b1ee-61ee44583518';
