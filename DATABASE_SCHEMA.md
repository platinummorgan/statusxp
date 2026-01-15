# StatusXP Database Schema Reference

**Last Updated:** January 15, 2026

> **IMPORTANT:** This is the authoritative source for database schema. Do not guess table or column names - reference this document.

---

## Core Tables

### profiles
Primary user account table.

```sql
CREATE TABLE public.profiles (
  id uuid NOT NULL PRIMARY KEY,
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
  psn_sync_status text DEFAULT 'never_synced'::text,
  psn_sync_error text,
  psn_sync_progress integer DEFAULT 0,
  subscription_tier text NOT NULL DEFAULT 'free'::text,
  subscription_expires_at timestamp with time zone,
  psn_avatar_url text,
  psn_is_plus boolean DEFAULT false,
  xbox_xuid text,
  xbox_access_token text,
  xbox_refresh_token text,
  xbox_token_expires_at timestamp with time zone,
  xbox_sync_status text DEFAULT 'never_synced'::text,
  last_xbox_sync_at timestamp with time zone,
  xbox_sync_error text,
  xbox_sync_progress integer DEFAULT 0,
  xbox_user_hash text,
  steam_sync_status text,
  steam_sync_progress integer DEFAULT 0,
  steam_sync_error text,
  last_steam_sync_at timestamp with time zone,
  steam_api_key text,
  preferred_display_platform text DEFAULT 'psn'::text,
  steam_display_name text,
  xbox_avatar_url text,
  steam_avatar_url text,
  merged_into_user_id uuid,
  merged_at timestamp with time zone,
  show_on_leaderboard boolean DEFAULT true,
  FOREIGN KEY (id) REFERENCES auth.users(id),
  FOREIGN KEY (merged_into_user_id) REFERENCES auth.users(id)
);
```

**Key Notes:**
- `profiles.id` references `auth.users(id)`
- There is NO `statusxp` column on this table
- StatusXP is calculated from `user_games.statusxp_effective`

---

## Game & Achievement Metadata

### game_titles
Game metadata across all platforms.

```sql
CREATE TABLE public.game_titles (
  id bigint NOT NULL PRIMARY KEY,
  name text NOT NULL,
  cover_url text,
  metadata jsonb DEFAULT '{}'::jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  platform_version text,
  psn_npwr_id text,
  xbox_title_id text,
  steam_app_id text,
  proxied_cover_url text
);
```

### achievements
Multi-platform achievement metadata (Xbox, Steam, and some PSN data).

```sql
CREATE TABLE public.achievements (
  id bigint NOT NULL PRIMARY KEY,
  game_title_id bigint,
  platform text NOT NULL CHECK (platform = ANY (ARRAY['psn'::text, 'xbox'::text, 'steam'::text])),
  platform_achievement_id text NOT NULL,
  name text NOT NULL,
  description text,
  icon_url text,
  psn_trophy_type text CHECK (psn_trophy_type = ANY (ARRAY['bronze'::text, 'silver'::text, 'gold'::text, 'platinum'::text, NULL::text])),
  xbox_gamerscore integer,
  xbox_is_secret boolean DEFAULT false,
  rarity_global numeric,
  is_dlc boolean DEFAULT false,
  dlc_name text,
  created_at timestamp with time zone DEFAULT now(),
  content_set text DEFAULT 'BASE'::text,
  is_platinum boolean DEFAULT false,
  include_in_score boolean DEFAULT true,
  rarity_band text,
  rarity_multiplier numeric,
  base_status_xp numeric,
  steam_hidden boolean DEFAULT false,
  rarity_last_updated_at timestamp with time zone,
  ai_guide text,
  ai_guide_generated_at timestamp with time zone,
  youtube_video_id text,
  platform_version text,
  proxied_icon_url text,
  FOREIGN KEY (game_title_id) REFERENCES public.game_titles(id)
);
```

**Key Notes:**
- `platform` column: 'psn', 'xbox', 'steam'
- `rarity_global` - numeric (percentage)
- `xbox_gamerscore` - integer (Xbox only)
- `psn_trophy_type` - 'bronze', 'silver', 'gold', 'platinum' (PSN only)

### trophies
PSN-specific trophy metadata (legacy table).

```sql
CREATE TABLE public.trophies (
  id bigint NOT NULL PRIMARY KEY,
  game_title_id bigint,
  name text NOT NULL,
  description text,
  tier text CHECK (tier = ANY (ARRAY['bronze'::text, 'silver'::text, 'gold'::text, 'platinum'::text])),
  icon_url text,
  rarity_global numeric,
  hidden boolean DEFAULT false,
  sort_order integer,
  created_at timestamp with time zone DEFAULT now(),
  proxied_icon_url text,
  FOREIGN KEY (game_title_id) REFERENCES public.game_titles(id)
);
```

**Key Notes:**
- `tier` column: 'bronze', 'silver', 'gold', 'platinum'
- `rarity_global` - numeric (percentage)

---

## User Progress Tables

### user_games
User's game collection and progress.

```sql
CREATE TABLE public.user_games (
  id bigint NOT NULL PRIMARY KEY,
  user_id uuid,
  game_title_id bigint,
  platform_id bigint,
  total_trophies integer DEFAULT 0,
  earned_trophies integer DEFAULT 0,
  completion_percent numeric DEFAULT 0,
  has_platinum boolean DEFAULT false,
  bronze_trophies integer DEFAULT 0,
  silver_trophies integer DEFAULT 0,
  gold_trophies integer DEFAULT 0,
  platinum_trophies integer DEFAULT 0,
  xbox_total_achievements integer DEFAULT 0,
  xbox_achievements_earned integer DEFAULT 0,
  xbox_current_gamerscore integer DEFAULT 0,
  xbox_max_gamerscore integer DEFAULT 0,
  xbox_last_updated_at timestamp with time zone,
  last_played_at timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  statusxp_raw numeric DEFAULT 0,
  statusxp_effective numeric DEFAULT 0,
  stack_index integer DEFAULT 1,
  stack_multiplier numeric DEFAULT 1.0,
  base_completed boolean DEFAULT false,
  last_rarity_sync timestamp with time zone,
  last_trophy_earned_at timestamp with time zone,
  rarest_earned_achievement_rarity numeric,
  sync_failed boolean DEFAULT false,
  sync_error text,
  last_sync_attempt timestamp with time zone,
  FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  FOREIGN KEY (game_title_id) REFERENCES public.game_titles(id),
  FOREIGN KEY (platform_id) REFERENCES public.platforms(id)
);
```

**Key Notes:**
- `statusxp_effective` - THIS IS THE MAIN STATUSXP VALUE (raw × stack_multiplier)
- `xbox_current_gamerscore` - user's earned gamerscore for this game (Xbox only)
- `xbox_max_gamerscore` - maximum possible gamerscore (Xbox only)

### user_trophies
PSN trophy unlocks.

```sql
CREATE TABLE public.user_trophies (
  id bigint NOT NULL PRIMARY KEY,
  user_id uuid,
  trophy_id bigint,
  earned_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  FOREIGN KEY (trophy_id) REFERENCES public.trophies(id)
);
```

**Key Notes:**
- NO `trophy_type` column - must join with `trophies` table
- NO `rarity` column - must join with `trophies` table to get `rarity_global`
- NO `platform` column - this table is PSN-only

**To get trophy type/rarity:**
```sql
SELECT user_trophies.*, trophies.tier, trophies.rarity_global
FROM user_trophies
JOIN trophies ON user_trophies.trophy_id = trophies.id
WHERE user_trophies.user_id = ?
```

### user_achievements
Multi-platform achievement unlocks (Xbox, Steam, and some PSN).

```sql
CREATE TABLE public.user_achievements (
  id bigint NOT NULL PRIMARY KEY,
  user_id uuid,
  achievement_id bigint,
  earned_at timestamp with time zone NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  statusxp_points numeric DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  FOREIGN KEY (achievement_id) REFERENCES public.achievements(id)
);
```

**Key Notes:**
- NO `platform` column - must join with `achievements` table
- NO `rarity` column - must join with `achievements` table to get `rarity_global`
- NO `gamerscore` column - must join with `achievements` table to get `xbox_gamerscore`

**To get platform/rarity/gamerscore:**
```sql
SELECT user_achievements.*, achievements.platform, achievements.rarity_global, achievements.xbox_gamerscore
FROM user_achievements
JOIN achievements ON user_achievements.achievement_id = achievements.id
WHERE user_achievements.user_id = ?
AND achievements.platform = 'xbox'  -- for filtering
```

---

## Meta Achievement System

### meta_achievements
Meta achievement definitions (site-wide achievements).

```sql
CREATE TABLE public.meta_achievements (
  id text NOT NULL PRIMARY KEY,
  category text NOT NULL,
  default_title text NOT NULL,
  description text NOT NULL,
  icon_emoji text,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  required_platforms ARRAY
);
```

**Key Notes:**
- `id` is text (e.g., 'psn_100_trophies', 'xbox_5000_gamerscore', 'cross_triple_threat')
- There are 133 meta achievements total

### user_meta_achievements
User's unlocked meta achievements.

```sql
CREATE TABLE public.user_meta_achievements (
  id bigint NOT NULL PRIMARY KEY,
  user_id uuid NOT NULL,
  achievement_id text NOT NULL,
  custom_title text,
  unlocked_at timestamp with time zone DEFAULT now(),
  FOREIGN KEY (user_id) REFERENCES auth.users(id),
  FOREIGN KEY (achievement_id) REFERENCES public.meta_achievements(id)
);
```

---

## Platform-Specific Tables

### psn_user_trophy_profile
User's PSN trophy profile summary.

```sql
CREATE TABLE public.psn_user_trophy_profile (
  user_id uuid NOT NULL PRIMARY KEY,
  psn_trophy_level integer NOT NULL,
  psn_trophy_progress integer NOT NULL,
  psn_trophy_tier integer NOT NULL,
  psn_earned_bronze integer DEFAULT 0,
  psn_earned_silver integer DEFAULT 0,
  psn_earned_gold integer DEFAULT 0,
  psn_earned_platinum integer DEFAULT 0,
  last_fetched_at timestamp with time zone DEFAULT now(),
  FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
```

### Sync Logs
- `psn_sync_log` - PSN sync history
- `xbox_sync_log` - Xbox sync history  
- `steam_sync_logs` - Steam sync history

### Leaderboard Caches
- `psn_leaderboard_cache` - PSN leaderboard data
- `xbox_leaderboard_cache` - Xbox leaderboard data
- `steam_leaderboard_cache` - Steam leaderboard data

---

## Common Query Patterns

### Get User's Total StatusXP
```sql
SELECT SUM(statusxp_effective) as total_statusxp
FROM user_games
WHERE user_id = ?
```

### Get PSN Trophy Stats with Types and Rarity
```sql
SELECT 
  ut.*,
  t.tier,
  t.rarity_global
FROM user_trophies ut
JOIN trophies t ON ut.trophy_id = t.id
WHERE ut.user_id = ?
```

### Get Xbox Achievement Stats with Platform, Rarity, Gamerscore
```sql
SELECT 
  ua.*,
  a.platform,
  a.rarity_global,
  a.xbox_gamerscore
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = ?
AND a.platform = 'xbox'
```

### Get Steam Achievement Stats with Platform, Rarity
```sql
SELECT 
  ua.*,
  a.platform,
  a.rarity_global
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = ?
AND a.platform = 'steam'
```

### Count Platform Achievements

**PSN (user_trophies has no platform column, it's PSN-only):**
```sql
SELECT COUNT(*) FROM user_trophies WHERE user_id = ?
```

**Xbox:**
```sql
SELECT COUNT(*)
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = ?
AND a.platform = 'xbox'
```

**Steam:**
```sql
SELECT COUNT(*)
FROM user_achievements ua
JOIN achievements a ON ua.achievement_id = a.id
WHERE ua.user_id = ?
AND a.platform = 'steam'
```

---

## Critical Reminders

1. **There is NO `user_profiles` table** - it's called `profiles`
2. **There is NO `statusxp` column on profiles** - calculate from `user_games.statusxp_effective`
3. **`user_trophies` has NO type/rarity columns** - join with `trophies` to get `tier` and `rarity_global`
4. **`user_achievements` has NO platform/rarity/gamerscore columns** - join with `achievements` to get these
5. **`user_trophies` is PSN-only** - there's no `platform` column to filter on
6. **`achievements.platform`** is the column for filtering Xbox vs Steam in `user_achievements`
7. **Trophy types:** `trophies.tier` = 'bronze'|'silver'|'gold'|'platinum'
8. **Achievement platform:** `achievements.platform` = 'psn'|'xbox'|'steam'
9. **Gamerscore:** `achievements.xbox_gamerscore` (Xbox only)
10. **Rarity:** `trophies.rarity_global` or `achievements.rarity_global` (numeric percentage)

---

## Schema Validation Queries

Run these to verify schema assumptions:

```sql
-- Verify user_trophies columns (should NOT have trophy_type, rarity, platform)
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'user_trophies';

-- Verify trophies columns (should have tier, rarity_global)
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'trophies';

-- Verify user_achievements columns (should NOT have platform, rarity, gamerscore)
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'user_achievements';

-- Verify achievements columns (should have platform, rarity_global, xbox_gamerscore)
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'achievements';

-- Verify profiles columns (should NOT have statusxp)
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'profiles';

-- Verify user_games columns (should have statusxp_effective)
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'user_games';
```
