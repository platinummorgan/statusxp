-- Add DELETE policy for achievement_comments
-- Users can only delete their own comments

CREATE POLICY "Users can delete their own comments"
ON achievement_comments
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);
