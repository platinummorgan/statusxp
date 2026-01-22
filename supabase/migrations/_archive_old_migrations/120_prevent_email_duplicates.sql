-- Migration: Prevent duplicate accounts with same email across auth providers
-- Detects when a new user signs up with an email that already exists
-- and prevents creating a duplicate profile

-- Function to check for existing email before creating profile
CREATE OR REPLACE FUNCTION prevent_duplicate_email_profiles()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  existing_user_id UUID;
  existing_provider TEXT;
BEGIN
  -- Check if another auth.users record exists with same email
  SELECT au.id, au.raw_app_meta_data->>'provider' INTO existing_user_id, existing_provider
  FROM auth.users au
  WHERE LOWER(au.email) = LOWER(NEW.email)
    AND au.id != NEW.id
    AND au.email IS NOT NULL
  LIMIT 1;

  -- If duplicate email found, raise exception to prevent profile creation
  IF existing_user_id IS NOT NULL THEN
    RAISE EXCEPTION 'An account with email % already exists (provider: %). Please sign in with that account instead.', 
      NEW.email, 
      COALESCE(existing_provider, 'email');
  END IF;

  RETURN NEW;
END;
$$;

-- Add trigger on auth.users BEFORE INSERT
-- This fires when Supabase creates a new auth user
DROP TRIGGER IF EXISTS check_duplicate_email_on_signup ON auth.users;
CREATE TRIGGER check_duplicate_email_on_signup
  BEFORE INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION prevent_duplicate_email_profiles();

COMMENT ON FUNCTION prevent_duplicate_email_profiles IS 
  'Prevents duplicate accounts with same email across different auth providers (Apple, Google, email/password)';
