-- Migration: 010_add_psn_profile_fields.sql
-- Created: 2025-12-04
-- Description: Add PSN profile fields (onlineId, avatar, PS Plus status)

-- Add PSN profile fields to profiles table
alter table profiles
  add column if not exists psn_avatar_url text,
  add column if not exists psn_is_plus boolean default false;

-- Update existing psn_online_id column comment for clarity
comment on column profiles.psn_online_id is 'PSN Online ID (username) fetched from PSN API';
comment on column profiles.psn_avatar_url is 'PSN avatar URL (typically medium size)';
comment on column profiles.psn_is_plus is 'Whether user has PlayStation Plus subscription';

-- Create index for quick PS Plus lookups (if we want to show Plus-only features)
create index if not exists idx_profiles_psn_is_plus on profiles(psn_is_plus) where psn_is_plus = true;
