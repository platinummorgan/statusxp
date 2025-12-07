-- QUICK FIX: Run this in Supabase SQL Editor NOW
-- This adds the missing columns to the profiles table

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS preferred_display_platform text DEFAULT 'psn' CHECK (preferred_display_platform IN ('psn', 'steam', 'xbox'));

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS steam_display_name text;

-- That's it! Refresh your app after running this.
