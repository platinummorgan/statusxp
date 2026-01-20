-- Fix user_achievements RLS policies
-- The current policies check CURRENT_USER = 'service_role' which doesn't work with Supabase client
-- Service role key should bypass RLS entirely

-- Drop broken policies
DROP POLICY IF EXISTS user_achievements_modify_insert ON user_achievements;
DROP POLICY IF EXISTS user_achievements_modify_update ON user_achievements;
DROP POLICY IF EXISTS user_achievements_modify_delete ON user_achievements;

-- Create correct policies that allow service role (via JWT) and users for their own data
CREATE POLICY user_achievements_insert_policy ON user_achievements
  FOR INSERT
  WITH CHECK (
    auth.role() = 'service_role' 
    OR auth.uid() = user_id
  );

CREATE POLICY user_achievements_update_policy ON user_achievements
  FOR UPDATE
  USING (
    auth.role() = 'service_role'
    OR auth.uid() = user_id
  );

CREATE POLICY user_achievements_delete_policy ON user_achievements
  FOR DELETE
  USING (
    auth.role() = 'service_role'
    OR auth.uid() = user_id
  );

-- Test insert with DanyGT37's data
INSERT INTO user_achievements (user_id, achievement_id, earned_at)
VALUES (
  '68de8222-9da5-4362-ac9b-96b302a7d455',
  86351,  -- "Long Jump" from Portal
  NOW()
)
ON CONFLICT (user_id, achievement_id) DO NOTHING;

-- Check if it worked
SELECT COUNT(*) as test_insert_count
FROM user_achievements
WHERE user_id = '68de8222-9da5-4362-ac9b-96b302a7d455';
