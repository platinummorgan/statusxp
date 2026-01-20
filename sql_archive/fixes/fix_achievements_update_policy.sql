-- Enable UPDATE permission for authenticated users on achievements table
-- This allows the Supabase anon key to update ai_guide and ai_guide_generated_at columns

-- Drop the policy if it already exists
DROP POLICY IF EXISTS "Allow anon users to update AI guides" ON achievements;

-- Create a policy that allows anon/authenticated users to update AI guide fields
CREATE POLICY "Allow anon users to update AI guides"
ON achievements
FOR UPDATE
TO anon, authenticated
USING (true)  -- Allow reading any row
WITH CHECK (true);  -- Allow updating any row

-- Alternative: More restrictive policy that only allows updating specific columns
-- To use this instead, comment out the above policy and uncomment below:
/*
DROP POLICY IF EXISTS "Allow AI guide updates" ON achievements;

CREATE POLICY "Allow AI guide updates"
ON achievements
FOR UPDATE
TO anon, authenticated
USING (true)
WITH CHECK (
  -- Only allow updating AI guide related columns
  (ai_guide IS NOT DISTINCT FROM EXCLUDED.ai_guide) OR
  (ai_guide_generated_at IS NOT DISTINCT FROM EXCLUDED.ai_guide_generated_at)
);
*/
