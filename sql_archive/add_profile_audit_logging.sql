-- Add audit logging to track who/what is changing show_on_leaderboard

-- Create audit log table
CREATE TABLE IF NOT EXISTS profiles_audit_log (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL,
  field_changed TEXT NOT NULL,
  old_value TEXT,
  new_value TEXT,
  changed_by UUID,
  changed_at TIMESTAMPTZ DEFAULT NOW(),
  operation TEXT
);

-- Create trigger function to log changes
CREATE OR REPLACE FUNCTION log_profile_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.show_on_leaderboard IS DISTINCT FROM NEW.show_on_leaderboard THEN
    INSERT INTO profiles_audit_log (user_id, field_changed, old_value, new_value, changed_by, operation)
    VALUES (NEW.id, 'show_on_leaderboard', OLD.show_on_leaderboard::text, NEW.show_on_leaderboard::text, auth.uid(), TG_OP);
  END IF;
  
  RETURN NEW;
END;
$$;

-- Add trigger to profiles table
DROP TRIGGER IF EXISTS audit_profile_changes ON profiles;
CREATE TRIGGER audit_profile_changes
AFTER UPDATE ON profiles
FOR EACH ROW
EXECUTE FUNCTION log_profile_changes();

-- Check current audit log for Dex-Morgan
SELECT * FROM profiles_audit_log 
WHERE user_id = '84b60ad6-cb2c-484f-8953-bf814551fd7a'
ORDER BY changed_at DESC;
