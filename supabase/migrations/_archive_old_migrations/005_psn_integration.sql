-- Migration: 005_psn_integration.sql
-- Created: 2025-12-02
-- Description: Add PlayStation Network integration support

-- ============================================================================
-- PROFILES - Add PSN integration fields
-- ============================================================================
alter table profiles 
  add column psn_account_id text,
  add column psn_npsso_token text,
  add column psn_access_token text,
  add column psn_refresh_token text,
  add column psn_token_expires_at timestamptz,
  add column last_psn_sync_at timestamptz,
  add column psn_sync_status text default 'never_synced' check (psn_sync_status in ('never_synced', 'pending', 'syncing', 'success', 'error')),
  add column psn_sync_error text,
  add column psn_sync_progress int default 0;

create index idx_profiles_psn_account_id on profiles(psn_account_id) where psn_account_id is not null;
create index idx_profiles_psn_sync_status on profiles(psn_sync_status);

comment on column profiles.psn_account_id is 'PlayStation Network account ID';
comment on column profiles.psn_npsso_token is 'Encrypted NPSSO token for PSN authentication';
comment on column profiles.psn_access_token is 'Current PSN API access token';
comment on column profiles.psn_refresh_token is 'PSN refresh token for obtaining new access tokens';
comment on column profiles.psn_token_expires_at is 'Expiration timestamp for the current access token';
comment on column profiles.last_psn_sync_at is 'Last successful PSN trophy sync timestamp';
comment on column profiles.psn_sync_status is 'Current status of PSN sync process';
comment on column profiles.psn_sync_error is 'Error message from last failed sync';
comment on column profiles.psn_sync_progress is 'Percentage progress of current sync (0-100)';

-- ============================================================================
-- GAME TITLES - Add PSN metadata
-- ============================================================================
alter table game_titles
  add column psn_np_communication_id text,
  add column psn_np_title_id text,
  add column psn_np_service_name text check (psn_np_service_name in ('trophy', 'trophy2', null)),
  add column psn_trophy_set_version text,
  add column psn_has_trophy_groups boolean default false;

create index idx_game_titles_psn_np_communication_id on game_titles(psn_np_communication_id) where psn_np_communication_id is not null;
create index idx_game_titles_psn_np_title_id on game_titles(psn_np_title_id) where psn_np_title_id is not null;

comment on column game_titles.psn_np_communication_id is 'PSN unique ID for trophy retrieval';
comment on column game_titles.psn_np_title_id is 'PSN title ID (CUSA/PPSA format)';
comment on column game_titles.psn_np_service_name is 'PSN service name: trophy (PS3/PS4/Vita) or trophy2 (PS5)';
comment on column game_titles.psn_trophy_set_version is 'Version of the PSN trophy set';
comment on column game_titles.psn_has_trophy_groups is 'Whether game has multiple trophy groups (DLC)';

-- ============================================================================
-- TROPHIES - Add PSN metadata
-- ============================================================================
alter table trophies
  add column psn_trophy_id int,
  add column psn_trophy_group_id text default 'default',
  add column psn_trophy_type text check (psn_trophy_type in ('bronze', 'silver', 'gold', 'platinum', null)),
  add column psn_is_secret boolean default false,
  add column psn_earn_rate numeric(5,2);

create index idx_trophies_psn_trophy_id on trophies(game_title_id, psn_trophy_id);
create index idx_trophies_psn_trophy_group on trophies(game_title_id, psn_trophy_group_id);

comment on column trophies.psn_trophy_id is 'PSN trophy ID within the game';
comment on column trophies.psn_trophy_group_id is 'PSN trophy group (default, 001, 002 for DLC)';
comment on column trophies.psn_trophy_type is 'PSN trophy type/grade';
comment on column trophies.psn_is_secret is 'PSN hidden/secret trophy flag';
comment on column trophies.psn_earn_rate is 'Global percentage of players who earned this trophy';

-- ============================================================================
-- USER GAMES - Add PSN progress tracking
-- ============================================================================
alter table user_games
  add column psn_progress_data jsonb default '{}'::jsonb,
  add column psn_last_updated_at timestamptz;

create index idx_user_games_psn_progress on user_games using gin(psn_progress_data);

comment on column user_games.psn_progress_data is 'PSN-specific progress data including trophy groups';
comment on column user_games.psn_last_updated_at is 'Last time PSN data was fetched for this game';

-- ============================================================================
-- PSN SYNC LOG
-- ============================================================================
create table psn_sync_log (
  id bigserial primary key,
  user_id uuid references profiles(id) on delete cascade,
  sync_type text not null check (sync_type in ('full', 'incremental', 'single_game')),
  status text not null check (status in ('started', 'in_progress', 'completed', 'failed')),
  games_processed int default 0,
  games_total int default 0,
  trophies_added int default 0,
  trophies_updated int default 0,
  error_message text,
  started_at timestamptz default now(),
  completed_at timestamptz,
  metadata jsonb default '{}'::jsonb
);

create index idx_psn_sync_log_user on psn_sync_log(user_id, started_at desc);
create index idx_psn_sync_log_status on psn_sync_log(status);

comment on table psn_sync_log is 'Log of PSN trophy sync operations';

-- ============================================================================
-- PSN TROPHY GROUPS (for DLC tracking)
-- ============================================================================
create table psn_trophy_groups (
  id bigserial primary key,
  game_title_id bigint references game_titles(id) on delete cascade,
  trophy_group_id text not null,
  trophy_group_name text not null,
  trophy_group_detail text,
  trophy_group_icon_url text,
  trophy_count_bronze int default 0,
  trophy_count_silver int default 0,
  trophy_count_gold int default 0,
  trophy_count_platinum int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (game_title_id, trophy_group_id)
);

create index idx_psn_trophy_groups_game_title on psn_trophy_groups(game_title_id);

comment on table psn_trophy_groups is 'PSN trophy groups for games with DLC';

-- ============================================================================
-- PSN USER TROPHY PROFILE (summary stats from PSN)
-- ============================================================================
create table psn_user_trophy_profile (
  user_id uuid primary key references profiles(id) on delete cascade,
  psn_trophy_level int not null,
  psn_trophy_progress int not null,
  psn_trophy_tier int not null,
  psn_earned_bronze int default 0,
  psn_earned_silver int default 0,
  psn_earned_gold int default 0,
  psn_earned_platinum int default 0,
  last_fetched_at timestamptz default now()
);

comment on table psn_user_trophy_profile is 'PSN account trophy summary and level';
