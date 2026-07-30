-- Notification delivery did not exist when these preferences were introduced,
-- so prior true values cannot be treated as informed OS-notification consent.
ALTER TABLE public.user_notification_preferences
  ALTER COLUMN push_enabled SET DEFAULT false;

UPDATE public.user_notification_preferences
SET push_enabled = false,
    updated_at = now()
WHERE push_enabled = true;
