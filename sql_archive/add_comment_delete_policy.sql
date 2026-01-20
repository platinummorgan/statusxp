-- Add DELETE policy for achievement_comments
-- Users can only delete their own comments
-- Super admin (developer) can delete any comment

DROP POLICY IF EXISTS "Users can delete their own comments" ON achievement_comments;

CREATE POLICY "Users can delete their own comments or admin can delete any"
ON achievement_comments
FOR DELETE
TO authenticated
USING (
  auth.uid() = user_id 
  OR 
  auth.uid() = '84b60ad6-cb2c-484f-8953-bf814551fd7a'::uuid  -- Super admin
);

-- To find your user ID, run this query:
-- SELECT auth.uid();
-- Or check: SELECT id FROM auth.users WHERE email = 'your-email@example.com';
