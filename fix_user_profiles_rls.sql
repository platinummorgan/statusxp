-- Allow anyone to read user profiles (for public profiles feature)
-- Drop if exists, then create
DROP POLICY IF EXISTS "Anyone can view profiles" ON public.profiles;

CREATE POLICY "Anyone can view profiles"
  ON public.profiles FOR SELECT
  USING (true);
