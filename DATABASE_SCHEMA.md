-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.achievement_comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  achievement_id bigint NOT NULL,
  user_id uuid NOT NULL,
  comment_text text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  is_hidden boolean DEFAULT false,
  is_flagged boolean DEFAULT false,
  flag_count integer DEFAULT 0,
  CONSTRAINT achievement_comments_pkey PRIMARY KEY (id),
  CONSTRAINT achievement_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.achievements (
  platform_id bigint NOT NULL,
  platform_game_id text NOT NULL,
  platform_achievement_id text NOT NULL,
  name text NOT NULL,
  description text,
  icon_url text,
  rarity_global numeric,
  score_value integer DEFAULT 0,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  base_status_xp numeric DEFAULT 10,
  rarity_multiplier numeric DEFAULT 1.00,
  include_in_score boolean DEFAULT true,
  is_platinum boolean DEFAULT false,
  proxied_icon_url text,
  CONSTRAINT achievements_pkey PRIMARY KEY (platform_id, platform_game_id, platform_achievement_id),
  CONSTRAINT achievements_platform_id_platform_game_id_fkey FOREIGN KEY (platform_id) REFERENCES public.games(platform_id),
  CONSTRAINT achievements_platform_id_platform_game_id_fkey FOREIGN KEY (platform_game_id) REFERENCES public.games(platform_id),
  CONSTRAINT achievements_platform_id_platform_game_id_fkey FOREIGN KEY (platform_id) REFERENCES public.games(platform_game_id),
  CONSTRAINT achievements_platform_id_platform_game_id_fkey FOREIGN KEY (platform_game_id) REFERENCES public.games(platform_game_id)
);
CREATE TABLE public.display_case_items (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  trophy_id integer NOT NULL,
  display_type text NOT NULL CHECK (display_type = ANY (ARRAY['trophyIcon'::text, 'gameCover'::text, 'figurine'::text, 'custom'::text])),
  shelf_number integer NOT NULL CHECK (shelf_number >= 0),
  position_in_shelf integer NOT NULL CHECK (position_in_shelf >= 0 AND position_in_shelf < 10),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT display_case_items_pkey PRIMARY KEY (id),
  CONSTRAINT display_case_items_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.flex_room_data (
  user_id uuid NOT NULL,
  tagline text DEFAULT 'Completionist'::text,
  last_updated timestamp with time zone DEFAULT now(),
  flex_of_all_time_platform_id bigint,
  flex_of_all_time_platform_game_id text,
  flex_of_all_time_platform_achievement_id text,
  rarest_flex_platform_id bigint,
  rarest_flex_platform_game_id text,
  rarest_flex_platform_achievement_id text,
  most_time_sunk_platform_id bigint,
  most_time_sunk_platform_game_id text,
  most_time_sunk_platform_achievement_id text,
  sweatiest_platinum_platform_id bigint,
  sweatiest_platinum_platform_game_id text,
  sweatiest_platinum_platform_achievement_id text,
  superlatives jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT flex_room_data_pkey PRIMARY KEY (user_id),
  CONSTRAINT flex_room_data_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_game_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_achievement_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_game_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_achievement_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_game_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT fk_flex_of_all_time FOREIGN KEY (flex_of_all_time_platform_achievement_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT fk_rarest_flex FOREIGN KEY (rarest_flex_platform_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_rarest_flex FOREIGN KEY (rarest_flex_platform_game_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_rarest_flex FOREIGN KEY (rarest_flex_platform_achievement_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_rarest_flex FOREIGN KEY (rarest_flex_platform_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_rarest_flex FOREIGN KEY (rarest_flex_platform_game_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_rarest_flex FOREIGN KEY (rarest_flex_platform_achievement_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_rarest_flex FOREIGN KEY (rarest_flex_platform_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT fk_rarest_flex FOREIGN KEY (rarest_flex_platform_game_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT fk_rarest_flex FOREIGN KEY (rarest_flex_platform_achievement_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT fk_most_time_sunk FOREIGN KEY (most_time_sunk_platform_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_most_time_sunk FOREIGN KEY (most_time_sunk_platform_game_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_most_time_sunk FOREIGN KEY (most_time_sunk_platform_achievement_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_most_time_sunk FOREIGN KEY (most_time_sunk_platform_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_most_time_sunk FOREIGN KEY (most_time_sunk_platform_game_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_most_time_sunk FOREIGN KEY (most_time_sunk_platform_achievement_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_most_time_sunk FOREIGN KEY (most_time_sunk_platform_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT fk_most_time_sunk FOREIGN KEY (most_time_sunk_platform_game_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT fk_most_time_sunk FOREIGN KEY (most_time_sunk_platform_achievement_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT fk_sweatiest_platinum FOREIGN KEY (sweatiest_platinum_platform_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_sweatiest_platinum FOREIGN KEY (sweatiest_platinum_platform_game_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_sweatiest_platinum FOREIGN KEY (sweatiest_platinum_platform_achievement_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT fk_sweatiest_platinum FOREIGN KEY (sweatiest_platinum_platform_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_sweatiest_platinum FOREIGN KEY (sweatiest_platinum_platform_game_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_sweatiest_platinum FOREIGN KEY (sweatiest_platinum_platform_achievement_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT fk_sweatiest_platinum FOREIGN KEY (sweatiest_platinum_platform_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT fk_sweatiest_platinum FOREIGN KEY (sweatiest_platinum_platform_game_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT fk_sweatiest_platinum FOREIGN KEY (sweatiest_platinum_platform_achievement_id) REFERENCES public.achievements(platform_achievement_id)
);
CREATE TABLE public.game_groups (
  id bigint NOT NULL DEFAULT nextval('game_groups_id_seq'::regclass),
  group_key text NOT NULL,
  game_title_ids ARRAY NOT NULL,
  primary_game_id bigint NOT NULL,
  platforms ARRAY,
  similarity_score numeric,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT game_groups_pkey PRIMARY KEY (id)
);
CREATE TABLE public.game_groups_refresh_queue (
  id bigint NOT NULL DEFAULT nextval('game_groups_refresh_queue_id_seq'::regclass),
  needs_refresh boolean DEFAULT true,
  last_refresh_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT game_groups_refresh_queue_pkey PRIMARY KEY (id)
);
CREATE TABLE public.games (
  platform_id bigint NOT NULL,
  platform_game_id text NOT NULL,
  name text NOT NULL,
  cover_url text,
  icon_url text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT games_pkey PRIMARY KEY (platform_id, platform_game_id),
  CONSTRAINT games_platform_id_fkey FOREIGN KEY (platform_id) REFERENCES public.platforms(id)
);
CREATE TABLE public.leaderboard_cache (
  user_id uuid NOT NULL,
  total_statusxp bigint NOT NULL DEFAULT 0,
  total_game_entries integer NOT NULL DEFAULT 0,
  last_updated timestamp with time zone DEFAULT now(),
  CONSTRAINT leaderboard_cache_pkey PRIMARY KEY (user_id),
  CONSTRAINT leaderboard_cache_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.meta_achievements (
  id text NOT NULL,
  category text NOT NULL,
  default_title text NOT NULL,
  description text NOT NULL,
  icon_emoji text,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  required_platforms ARRAY,
  CONSTRAINT meta_achievements_pkey PRIMARY KEY (id)
);
CREATE TABLE public.platforms (
  id bigint NOT NULL DEFAULT nextval('platforms_id_seq'::regclass),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  primary_color text,
  accent_color text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT platforms_pkey PRIMARY KEY (id)
);
CREATE TABLE public.profile_themes (
  id bigint NOT NULL DEFAULT nextval('profile_themes_id_seq'::regclass),
  code text NOT NULL UNIQUE,
  name text NOT NULL,
  background_color text,
  primary_color text,
  accent_color text,
  text_color text,
  metadata jsonb DEFAULT '{}'::jsonb,
  CONSTRAINT profile_themes_pkey PRIMARY KEY (id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  username text NOT NULL UNIQUE,
  display_name text,
  avatar_url text,
  psn_online_id text,
  xbox_gamertag text,
  steam_id text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  psn_account_id text,
  psn_npsso_token text,
  psn_access_token text,
  psn_refresh_token text,
  psn_token_expires_at timestamp with time zone,
  last_psn_sync_at timestamp with time zone,
  psn_sync_status text DEFAULT 'never_synced'::text CHECK (psn_sync_status = ANY (ARRAY['never_synced'::text, 'pending'::text, 'syncing'::text, 'success'::text, 'error'::text, 'stopped'::text, 'cancelling'::text])),
  psn_sync_error text,
  psn_sync_progress integer DEFAULT 0,
  subscription_tier text NOT NULL DEFAULT 'free'::text CHECK (subscription_tier = ANY (ARRAY['free'::text, 'premium'::text])),
  subscription_expires_at timestamp with time zone,
  psn_avatar_url text,
  psn_is_plus boolean DEFAULT false,
  xbox_xuid text,
  xbox_access_token text,
  xbox_refresh_token text,
  xbox_token_expires_at timestamp with time zone,
  xbox_sync_status text DEFAULT 'never_synced'::text CHECK (xbox_sync_status = ANY (ARRAY['never_synced'::text, 'pending'::text, 'syncing'::text, 'success'::text, 'error'::text, 'stopped'::text, 'cancelling'::text])),
  last_xbox_sync_at timestamp with time zone,
  xbox_sync_error text,
  xbox_sync_progress integer DEFAULT 0,
  xbox_user_hash text,
  steam_sync_status text CHECK (steam_sync_status = ANY (ARRAY['never_synced'::text, 'pending'::text, 'syncing'::text, 'success'::text, 'error'::text, 'stopped'::text, 'cancelling'::text])),
  steam_sync_progress integer DEFAULT 0,
  steam_sync_error text,
  last_steam_sync_at timestamp with time zone,
  steam_api_key text,
  preferred_display_platform text DEFAULT 'psn'::text CHECK (preferred_display_platform = ANY (ARRAY['psn'::text, 'steam'::text, 'xbox'::text])),
  steam_display_name text,
  xbox_avatar_url text,
  steam_avatar_url text,
  merged_into_user_id uuid,
  merged_at timestamp with time zone,
  show_on_leaderboard boolean DEFAULT true,
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id),
  CONSTRAINT profiles_merged_into_user_id_fkey FOREIGN KEY (merged_into_user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.psn_sync_logs (
  id bigint NOT NULL DEFAULT nextval('psn_sync_logs_id_seq'::regclass),
  user_id uuid,
  sync_type text NOT NULL CHECK (sync_type = ANY (ARRAY['full'::text, 'incremental'::text])),
  status text NOT NULL CHECK (status = ANY (ARRAY['pending'::text, 'syncing'::text, 'completed'::text, 'failed'::text])),
  started_at timestamp with time zone NOT NULL,
  completed_at timestamp with time zone,
  games_processed integer DEFAULT 0,
  trophies_synced integer DEFAULT 0,
  games_processed_ids ARRAY DEFAULT '{}'::text[],
  error_message text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT psn_sync_logs_pkey PRIMARY KEY (id),
  CONSTRAINT psn_sync_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.psn_user_trophy_profile (
  user_id uuid NOT NULL,
  psn_trophy_level integer NOT NULL,
  psn_trophy_progress integer NOT NULL,
  psn_trophy_tier integer NOT NULL,
  psn_earned_bronze integer DEFAULT 0,
  psn_earned_silver integer DEFAULT 0,
  psn_earned_gold integer DEFAULT 0,
  psn_earned_platinum integer DEFAULT 0,
  last_fetched_at timestamp with time zone DEFAULT now(),
  CONSTRAINT psn_user_trophy_profile_pkey PRIMARY KEY (user_id),
  CONSTRAINT psn_user_trophy_profile_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.steam_sync_logs (
  id bigint NOT NULL DEFAULT nextval('steam_sync_logs_id_seq'::regclass),
  user_id uuid,
  sync_type text NOT NULL CHECK (sync_type = ANY (ARRAY['full'::text, 'incremental'::text])),
  status text NOT NULL CHECK (status = ANY (ARRAY['pending'::text, 'syncing'::text, 'completed'::text, 'failed'::text])),
  started_at timestamp with time zone NOT NULL,
  completed_at timestamp with time zone,
  games_processed integer DEFAULT 0,
  achievements_synced integer DEFAULT 0,
  games_processed_ids ARRAY DEFAULT '{}'::text[],
  error_message text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT steam_sync_logs_pkey PRIMARY KEY (id),
  CONSTRAINT steam_sync_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.trophy_help_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  game_id text NOT NULL,
  game_title text NOT NULL,
  achievement_id text NOT NULL,
  achievement_name text NOT NULL,
  platform text NOT NULL,
  description text,
  availability text,
  platform_username text,
  status text NOT NULL DEFAULT 'open'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT trophy_help_requests_pkey PRIMARY KEY (id),
  CONSTRAINT trophy_help_requests_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.trophy_help_responses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  request_id uuid NOT NULL,
  helper_user_id uuid NOT NULL,
  message text,
  status text NOT NULL DEFAULT 'pending'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT trophy_help_responses_pkey PRIMARY KEY (id),
  CONSTRAINT trophy_help_responses_helper_user_id_fkey FOREIGN KEY (helper_user_id) REFERENCES auth.users(id),
  CONSTRAINT trophy_help_responses_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.trophy_help_requests(id)
);
CREATE TABLE public.trophy_room_items (
  id bigint NOT NULL DEFAULT nextval('trophy_room_items_id_seq'::regclass),
  shelf_id bigint,
  slot_index integer NOT NULL,
  item_type text NOT NULL,
  trophy_id bigint,
  game_title_id bigint,
  label_override text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT trophy_room_items_pkey PRIMARY KEY (id),
  CONSTRAINT trophy_room_items_shelf_id_fkey FOREIGN KEY (shelf_id) REFERENCES public.trophy_room_shelves(id)
);
CREATE TABLE public.trophy_room_shelves (
  id bigint NOT NULL DEFAULT nextval('trophy_room_shelves_id_seq'::regclass),
  user_id uuid,
  name text NOT NULL,
  sort_order integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT trophy_room_shelves_pkey PRIMARY KEY (id),
  CONSTRAINT trophy_room_shelves_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.user_achievements (
  user_id uuid NOT NULL,
  platform_id bigint NOT NULL,
  platform_game_id text NOT NULL,
  platform_achievement_id text NOT NULL,
  earned_at timestamp with time zone NOT NULL,
  synced_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_achievements_pkey PRIMARY KEY (user_id, platform_id, platform_game_id, platform_achievement_id),
  CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_game_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_achievement_id) REFERENCES public.achievements(platform_id),
  CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_game_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_achievement_id) REFERENCES public.achievements(platform_game_id),
  CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_game_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT user_achievements_v2_platform_id_platform_game_id_platform_fkey FOREIGN KEY (platform_achievement_id) REFERENCES public.achievements(platform_achievement_id),
  CONSTRAINT user_achievements_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.user_ai_credits (
  user_id uuid NOT NULL,
  pack_credits integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_ai_credits_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_ai_credits_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_ai_daily_usage (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  usage_date date DEFAULT CURRENT_DATE,
  uses_today integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  source text CHECK (source = ANY (ARRAY['daily_free'::text, 'pack'::text, 'premium'::text])),
  CONSTRAINT user_ai_daily_usage_pkey PRIMARY KEY (id),
  CONSTRAINT user_ai_daily_usage_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_ai_pack_purchases (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  pack_type character varying NOT NULL,
  credits_purchased integer NOT NULL,
  price_paid numeric,
  purchase_date timestamp with time zone DEFAULT now(),
  platform character varying,
  CONSTRAINT user_ai_pack_purchases_pkey PRIMARY KEY (id),
  CONSTRAINT user_ai_pack_purchases_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_meta_achievements (
  id bigint NOT NULL DEFAULT nextval('user_meta_achievements_id_seq'::regclass),
  user_id uuid NOT NULL,
  achievement_id text NOT NULL,
  custom_title text,
  unlocked_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_meta_achievements_pkey PRIMARY KEY (id),
  CONSTRAINT user_meta_achievements_achievement_id_fkey FOREIGN KEY (achievement_id) REFERENCES public.meta_achievements(id),
  CONSTRAINT user_meta_achievements_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_premium_status (
  user_id uuid NOT NULL,
  is_premium boolean DEFAULT false,
  premium_since timestamp with time zone,
  premium_expires_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  monthly_ai_credits integer DEFAULT 100,
  ai_credits_refreshed_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_premium_status_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_premium_status_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_profile_settings (
  user_id uuid NOT NULL,
  profile_theme_id bigint,
  is_profile_public boolean DEFAULT true,
  show_rarest_trophy boolean DEFAULT true,
  show_hardest_platinum boolean DEFAULT true,
  show_completed_games boolean DEFAULT true,
  time_zone text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_profile_settings_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_profile_settings_profile_theme_id_fkey FOREIGN KEY (profile_theme_id) REFERENCES public.profile_themes(id),
  CONSTRAINT user_profile_settings_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.user_progress (
  user_id uuid NOT NULL,
  platform_id bigint NOT NULL,
  platform_game_id text NOT NULL,
  current_score integer DEFAULT 0,
  achievements_earned integer DEFAULT 0,
  total_achievements integer DEFAULT 0,
  completion_percentage numeric DEFAULT 0,
  first_played_at timestamp with time zone,
  last_played_at timestamp with time zone,
  synced_at timestamp with time zone DEFAULT now(),
  metadata jsonb DEFAULT '{}'::jsonb,
  last_achievement_earned_at timestamp with time zone,
  CONSTRAINT user_progress_pkey PRIMARY KEY (user_id, platform_id, platform_game_id),
  CONSTRAINT user_progress_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT user_progress_platform_id_platform_game_id_fkey FOREIGN KEY (platform_id) REFERENCES public.games(platform_id),
  CONSTRAINT user_progress_platform_id_platform_game_id_fkey FOREIGN KEY (platform_game_id) REFERENCES public.games(platform_id),
  CONSTRAINT user_progress_platform_id_platform_game_id_fkey FOREIGN KEY (platform_id) REFERENCES public.games(platform_game_id),
  CONSTRAINT user_progress_platform_id_platform_game_id_fkey FOREIGN KEY (platform_game_id) REFERENCES public.games(platform_game_id)
);
CREATE TABLE public.user_selected_title (
  user_id uuid NOT NULL,
  achievement_id text,
  custom_title text,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_selected_title_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_selected_title_achievement_id_fkey FOREIGN KEY (achievement_id) REFERENCES public.meta_achievements(id),
  CONSTRAINT user_selected_title_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_stats (
  user_id uuid NOT NULL,
  total_games integer DEFAULT 0,
  completed_games integer DEFAULT 0,
  total_trophies integer DEFAULT 0,
  bronze_count integer DEFAULT 0,
  silver_count integer DEFAULT 0,
  gold_count integer DEFAULT 0,
  platinum_count integer DEFAULT 0,
  total_gamerscore integer DEFAULT 0,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_stats_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_stats_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.user_sync_history (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  user_id uuid NOT NULL,
  platform character varying NOT NULL,
  synced_at timestamp with time zone DEFAULT now(),
  success boolean DEFAULT true,
  CONSTRAINT user_sync_history_pkey PRIMARY KEY (id),
  CONSTRAINT user_sync_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.xbox_sync_logs (
  id bigint NOT NULL DEFAULT nextval('xbox_sync_logs_id_seq'::regclass),
  user_id uuid,
  sync_type text NOT NULL CHECK (sync_type = ANY (ARRAY['full'::text, 'incremental'::text])),
  status text NOT NULL CHECK (status = ANY (ARRAY['pending'::text, 'syncing'::text, 'completed'::text, 'failed'::text])),
  started_at timestamp with time zone NOT NULL,
  completed_at timestamp with time zone,
  games_processed integer DEFAULT 0,
  achievements_synced integer DEFAULT 0,
  error_message text,
  created_at timestamp with time zone DEFAULT now(),
  games_processed_ids ARRAY DEFAULT '{}'::text[],
  CONSTRAINT xbox_sync_logs_pkey PRIMARY KEY (id),
  CONSTRAINT xbox_sync_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);