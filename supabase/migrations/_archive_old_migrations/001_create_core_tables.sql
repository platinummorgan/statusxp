-- Migration: 001_create_core_tables.sql
-- Created: 2025-12-02
-- Description: Core tables for StatusXP

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================================================
-- PROFILES
-- ============================================================================
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text,
  avatar_url text,
  psn_online_id text,
  xbox_gamertag text,
  steam_id text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_profiles_username on profiles(username);
create index idx_profiles_psn on profiles(psn_online_id) where psn_online_id is not null;
create index idx_profiles_xbox on profiles(xbox_gamertag) where xbox_gamertag is not null;
create index idx_profiles_steam on profiles(steam_id) where steam_id is not null;

-- ============================================================================
-- PLATFORMS
-- ============================================================================
create table platforms (
  id bigserial primary key,
  code text unique not null,
  name text not null,
  primary_color text,
  accent_color text,
  created_at timestamptz default now()
);

create index idx_platforms_code on platforms(code);

-- ============================================================================
-- GAME TITLES
-- ============================================================================
create table game_titles (
  id bigserial primary key,
  platform_id bigint references platforms(id),
  name text not null,
  edition text,
  external_id text,
  cover_url text,
  release_year int,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_game_titles_platform on game_titles(platform_id);
create index idx_game_titles_name on game_titles(name);
create index idx_game_titles_external_id on game_titles(external_id) where external_id is not null;
create index idx_game_titles_metadata on game_titles using gin(metadata);

-- ============================================================================
-- TROPHIES
-- ============================================================================
create table trophies (
  id bigserial primary key,
  game_title_id bigint references game_titles(id) on delete cascade,
  name text not null,
  description text,
  tier text not null,
  sort_order int default 0,
  icon_url text,
  external_id text,
  rarity_global numeric(5,2),
  hidden boolean default false,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_trophies_game_title on trophies(game_title_id);
create index idx_trophies_tier on trophies(tier);
create index idx_trophies_sort_order on trophies(game_title_id, sort_order);
create index idx_trophies_external_id on trophies(external_id) where external_id is not null;
create index idx_trophies_metadata on trophies using gin(metadata);

-- ============================================================================
-- USER GAMES
-- ============================================================================
create table user_games (
  id bigserial primary key,
  user_id uuid references profiles(id) on delete cascade,
  game_title_id bigint references game_titles(id),
  total_trophies int not null,
  earned_trophies int not null default 0,
  has_platinum boolean not null default false,
  completion_percent numeric(5,2) default 0.0,
  last_played_at timestamptz,
  user_rating int,
  is_favorite boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (user_id, game_title_id)
);

create index idx_user_games_user on user_games(user_id);
create index idx_user_games_game_title on user_games(game_title_id);
create index idx_user_games_completion on user_games(user_id, completion_percent desc);
create index idx_user_games_last_played on user_games(user_id, last_played_at desc nulls last);
create index idx_user_games_favorites on user_games(user_id) where is_favorite = true;

-- ============================================================================
-- USER TROPHIES
-- ============================================================================
create table user_trophies (
  id bigserial primary key,
  user_id uuid references profiles(id) on delete cascade,
  trophy_id bigint references trophies(id) on delete cascade,
  earned_at timestamptz,
  source text,
  notes text,
  created_at timestamptz default now(),
  unique (user_id, trophy_id)
);

create index idx_user_trophies_user on user_trophies(user_id);
create index idx_user_trophies_trophy on user_trophies(trophy_id);
create index idx_user_trophies_earned_at on user_trophies(user_id, earned_at desc nulls last);

-- ============================================================================
-- USER STATS
-- ============================================================================
create table user_stats (
  user_id uuid primary key references profiles(id) on delete cascade,
  total_platinums int default 0,
  total_games_tracked int default 0,
  total_trophies int default 0,
  rarest_trophy_id bigint,
  rarest_trophy_rarity numeric(5,2),
  hardest_platinum_game_id bigint,
  updated_at timestamptz default now()
);

create index idx_user_stats_total_platinums on user_stats(total_platinums desc);
create index idx_user_stats_total_trophies on user_stats(total_trophies desc);

-- ============================================================================
-- PROFILE THEMES
-- ============================================================================
create table profile_themes (
  id bigserial primary key,
  code text unique not null,
  name text not null,
  background_color text,
  primary_color text,
  accent_color text,
  text_color text,
  metadata jsonb default '{}'::jsonb
);

create index idx_profile_themes_code on profile_themes(code);

-- ============================================================================
-- USER PROFILE SETTINGS
-- ============================================================================
create table user_profile_settings (
  user_id uuid primary key references profiles(id) on delete cascade,
  profile_theme_id bigint references profile_themes(id),
  is_profile_public boolean default true,
  show_rarest_trophy boolean default true,
  show_hardest_platinum boolean default true,
  show_completed_games boolean default true,
  time_zone text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- ============================================================================
-- TROPHY ROOM
-- ============================================================================
create table trophy_room_shelves (
  id bigserial primary key,
  user_id uuid references profiles(id),
  name text not null,
  sort_order int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index idx_trophy_room_shelves_user on trophy_room_shelves(user_id, sort_order);

create table trophy_room_items (
  id bigserial primary key,
  shelf_id bigint references trophy_room_shelves(id) on delete cascade,
  slot_index int not null,
  item_type text not null,
  trophy_id bigint references trophies(id),
  game_title_id bigint references game_titles(id),
  label_override text,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (shelf_id, slot_index)
);

create index idx_trophy_room_items_shelf on trophy_room_items(shelf_id, slot_index);
create index idx_trophy_room_items_trophy on trophy_room_items(trophy_id) where trophy_id is not null;
create index idx_trophy_room_items_game on trophy_room_items(game_title_id) where game_title_id is not null;
