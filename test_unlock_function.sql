-- Test the function directly with your user ID
-- Replace with one of your existing achievement IDs from the 74 you have

SELECT unlock_achievement_if_new(
  '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid,
  'rare_air',
  NOW()
) as newly_unlocked;

-- Should return FALSE if achievement already exists
-- Should return TRUE if it's new (won't be for your existing achievements)
