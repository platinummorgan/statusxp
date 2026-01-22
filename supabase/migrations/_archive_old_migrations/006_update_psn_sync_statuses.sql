-- Migration: 006_update_psn_sync_statuses.sql
-- Created: 2025-12-02
-- Description: Add 'stopped' status to psn_sync_status constraint for batch processing

-- Update the check constraint to include 'stopped' status
alter table profiles 
  drop constraint profiles_psn_sync_status_check;

alter table profiles 
  add constraint profiles_psn_sync_status_check 
  check (psn_sync_status in ('never_synced', 'pending', 'syncing', 'success', 'error', 'stopped'));

comment on constraint profiles_psn_sync_status_check on profiles is 
  'Valid PSN sync statuses: never_synced (initial), pending (more to sync), syncing (active), success (complete), error (failed), stopped (paused by user)';
