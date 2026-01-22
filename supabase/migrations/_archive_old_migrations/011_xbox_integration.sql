-- Migration: 011_xbox_integration.sql
-- Created: 2025-12-05
-- Description: Add Xbox Live integration support for multi-platform achievement tracking

-- ============================================================================
-- PROFILES - Add Xbox integration fields
-- ============================================================================
alter table profiles 
  add column xbox_xuid text,
  add column xbox_gamertag text,
  add column xbox_access_token text,
  add column xbox_refresh_token text,
  add column xbox_token_expires_at timestamptz,
  add column last_xbox_sync_at timestamptz,
  add column xbox_sync_status text default 'never_synced' check (xbox_sync_status in ('never_synced', 'pending', 'syncing', 'success', 'error')),
  add column xbox_sync_error text,
  add column xbox_sync_progress int default 0;

create index idx_profiles_xbox_xuid on profiles(xbox_xuid) where xbox_xuid is not null;
create index idx_profiles_xbox_sync_status on profiles(xbox_sync_status);
create index idx_profiles_xbox_gamertag on profiles(xbox_gamertag) where xbox_gamertag is not null;

comment on column profiles.xbox_xuid is 'Xbox Live unique user identifier (XUID)';
comment on column profiles.xbox_gamertag is 'Xbox Live gamertag';
comment on column profiles.xbox_access_token is 'Current Xbox Live API access token';
comment on column profiles.xbox_refresh_token is 'Xbox refresh token for obtaining new access tokens';
comment on column profiles.xbox_token_expires_at is 'Expiration timestamp for the current access token';
comment on column profiles.last_xbox_sync_at is 'Last successful Xbox achievement sync timestamp';
comment on column profiles.xbox_sync_status is 'Current status of Xbox sync process';
comment on column profiles.xbox_sync_error is 'Error message from last failed sync';
comment on column profiles.xbox_sync_progress is 'Percentage progress of current sync (0-100)';

-- ============================================================================
-- GAME TITLES - Add Xbox metadata
-- ============================================================================
alter table game_titles
  add column xbox_title_id bigint,
  add column xbox_service_config_id text,
  add column xbox_product_id text,
  add column xbox_max_gamerscore int,
  add column xbox_total_achievements int;

create index idx_game_titles_xbox_title_id on game_titles(xbox_title_id) where xbox_title_id is not null;
create index idx_game_titles_xbox_product_id on game_titles(xbox_product_id) where xbox_product_id is not null;

comment on column game_titles.xbox_title_id is 'Xbox title ID (numeric identifier)';
comment on column game_titles.xbox_service_config_id is 'Xbox service configuration ID (SCID)';
comment on column game_titles.xbox_product_id is 'Xbox product ID in Microsoft Store';
comment on column game_titles.xbox_max_gamerscore is 'Maximum gamerscore available in base game';
comment on column game_titles.xbox_total_achievements is 'Total number of achievements in base game';

-- ============================================================================
-- ACHIEVEMENTS table (new unified table for all platforms)
-- ============================================================================
create table if not exists achievements (
  id bigserial primary key,
  game_title_id bigint references game_titles(id) on delete cascade,
  platform text not null check (platform in ('psn', 'xbox', 'steam')),
  platform_achievement_id text not null, -- Trophy ID, Achievement ID, or Steam achievement key
  name text not null,
  description text,
  icon_url text,
  
  -- Platform-specific fields (nullable)
  -- PSN
  psn_trophy_type text check (psn_trophy_type in ('bronze', 'silver', 'gold', 'platinum', null)),
  psn_trophy_group_id text,
  psn_is_secret boolean,
  
  -- Xbox
  xbox_gamerscore int,
  xbox_is_secret boolean,
  xbox_progression_state text check (xbox_progression_state in ('Unknown', 'Achieved', 'NotStarted', 'InProgress', null)),
  
  -- Steam
  steam_hidden boolean,
  
  -- Unified fields
  rarity_global numeric(5,2), -- Global percentage (PSN earn rate, Xbox rarity, Steam global %)
  is_dlc boolean default false,
  dlc_name text,
  
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  
  -- Ensure uniqueness per platform
  unique(game_title_id, platform, platform_achievement_id)
);

create index idx_achievements_game_platform on achievements(game_title_id, platform);
create index idx_achievements_platform on achievements(platform);
create index idx_achievements_dlc on achievements(is_dlc);
create index idx_achievements_rarity on achievements(rarity_global);

comment on table achievements is 'Unified achievements table for all platforms (PSN trophies, Xbox achievements, Steam achievements)';
comment on column achievements.platform_achievement_id is 'Platform-specific ID: PSN trophy_id, Xbox achievement_id, Steam API name';
comment on column achievements.rarity_global is 'Global rarity percentage across all players on that platform';
comment on column achievements.is_dlc is 'Whether this achievement belongs to DLC (important for Steam normalization)';

-- ============================================================================
-- USER ACHIEVEMENTS table (new unified table)
-- ============================================================================
create table if not exists user_achievements (
  id bigserial primary key,
  user_id uuid references profiles(id) on delete cascade,
  achievement_id bigint references achievements(id) on delete cascade,
  earned_at timestamptz not null,
  
  -- Platform-specific unlock data
  platform_unlock_data jsonb default '{}'::jsonb,
  
  created_at timestamptz default now(),
  
  unique(user_id, achievement_id)
);

create index idx_user_achievements_user on user_achievements(user_id, earned_at desc);
create index idx_user_achievements_achievement on user_achievements(achievement_id);
create index idx_user_achievements_earned_at on user_achievements(earned_at desc);

comment on table user_achievements is 'Tracks which achievements users have earned across all platforms';
comment on column user_achievements.platform_unlock_data is 'Platform-specific unlock metadata (unlock time, rare achievement status, etc)';

-- ============================================================================
-- USER GAMES - Add Xbox progress tracking
-- ============================================================================
alter table user_games
  add column xbox_progress_data jsonb default '{}'::jsonb,
  add column xbox_last_updated_at timestamptz,
  add column xbox_current_gamerscore int default 0,
  add column xbox_max_gamerscore int default 0,
  add column xbox_achievements_earned int default 0,
  add column xbox_total_achievements int default 0;

create index idx_user_games_xbox_progress on user_games using gin(xbox_progress_data);

comment on column user_games.xbox_progress_data is 'Xbox-specific progress data including achievement unlock details';
comment on column user_games.xbox_last_updated_at is 'Last time Xbox data was fetched for this game';
comment on column user_games.xbox_current_gamerscore is 'Current gamerscore earned by user';
comment on column user_games.xbox_max_gamerscore is 'Maximum gamerscore available';
comment on column user_games.xbox_achievements_earned is 'Number of achievements unlocked';
comment on column user_games.xbox_total_achievements is 'Total achievements in game';

-- ============================================================================
-- XBOX SYNC LOG
-- ============================================================================
create table xbox_sync_log (
  id bigserial primary key,
  user_id uuid references profiles(id) on delete cascade,
  sync_type text not null check (sync_type in ('full', 'incremental', 'single_game')),
  status text not null check (status in ('started', 'in_progress', 'completed', 'failed')),
  games_processed int default 0,
  games_total int default 0,
  achievements_added int default 0,
  achievements_updated int default 0,
  error_message text,
  started_at timestamptz default now(),
  completed_at timestamptz,
  metadata jsonb default '{}'::jsonb
);

create index idx_xbox_sync_log_user on xbox_sync_log(user_id, started_at desc);
create index idx_xbox_sync_log_status on xbox_sync_log(status, started_at desc);

comment on table xbox_sync_log is 'Audit log for Xbox Live achievement sync operations';

-- ============================================================================
-- VIRTUAL COMPLETIONS table (for StatusXP scoring)
-- ============================================================================
create table virtual_completions (
  id bigserial primary key,
  user_id uuid references profiles(id) on delete cascade,
  game_title_id bigint references game_titles(id) on delete cascade,
  platform text not null check (platform in ('psn', 'xbox', 'steam')),
  completion_type text not null check (completion_type in ('platinum', '100%', 'both')),
  
  -- Completion flags
  base_game_complete boolean default false,
  dlc_complete boolean default false,
  
  -- StatusXP calculation
  status_xp_earned numeric(10,2) default 0,
  rarity_multiplier numeric(5,2) default 1.0,
  difficulty_multiplier numeric(5,2) default 1.0,
  
  achieved_at timestamptz not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  
  unique(user_id, game_title_id, platform, completion_type)
);

create index idx_virtual_completions_user on virtual_completions(user_id, achieved_at desc);
create index idx_virtual_completions_game on virtual_completions(game_title_id);
create index idx_virtual_completions_platform on virtual_completions(platform);
create index idx_virtual_completions_xp on virtual_completions(status_xp_earned desc);

comment on table virtual_completions is 'Tracks game completions across platforms for StatusXP leaderboards';
comment on column virtual_completions.completion_type is 'platinum = base game only, 100% = base + all DLC, both = platinum exists + 100% achieved';
comment on column virtual_completions.base_game_complete is 'True when base game achievements are complete (equivalent to platinum/1000G)';
comment on column virtual_completions.dlc_complete is 'True when all DLC achievements are also complete';
comment on column virtual_completions.status_xp_earned is 'Calculated StatusXP points for this completion';

-- ============================================================================
-- Enable Row Level Security
-- ============================================================================
alter table achievements enable row level security;
alter table user_achievements enable row level security;
alter table virtual_completions enable row level security;
alter table xbox_sync_log enable row level security;

-- Achievements are public (read-only for all)
create policy "Achievements are viewable by everyone"
  on achievements for select
  using (true);

-- Users can view their own achievement unlocks
create policy "Users can view their own achievement unlocks"
  on user_achievements for select
  using (auth.uid() = user_id);

-- Users can view their own virtual completions
create policy "Users can view their own virtual completions"
  on virtual_completions for select
  using (auth.uid() = user_id);

-- Users can view their own Xbox sync logs
create policy "Users can view their own Xbox sync logs"
  on xbox_sync_log for select
  using (auth.uid() = user_id);

-- ============================================================================
-- Helper functions
-- ============================================================================

-- Function to calculate if base game is complete for Steam
create or replace function is_steam_base_game_complete(
  p_user_id uuid,
  p_game_title_id bigint
) returns boolean as $$
declare
  total_base_achievements int;
  earned_base_achievements int;
begin
  -- Count total base game achievements (excluding DLC)
  select count(*)
  into total_base_achievements
  from achievements
  where game_title_id = p_game_title_id
    and platform = 'steam'
    and is_dlc = false;
    
  -- Count earned base game achievements
  select count(*)
  into earned_base_achievements
  from user_achievements ua
  join achievements a on a.id = ua.achievement_id
  where ua.user_id = p_user_id
    and a.game_title_id = p_game_title_id
    and a.platform = 'steam'
    and a.is_dlc = false;
    
  return earned_base_achievements = total_base_achievements and total_base_achievements > 0;
end;
$$ language plpgsql;

comment on function is_steam_base_game_complete is 'Determines if user has completed base game on Steam (excluding DLC) for virtual platinum';
