-- Restore history tables referenced by seasonal leaderboard migrations.
-- These tables existed in the live database but were missing from the
-- repository migration chain, preventing clean local database rebuilds.

CREATE TABLE IF NOT EXISTS public.leaderboard_history (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rank integer NOT NULL,
  total_statusxp bigint NOT NULL DEFAULT 0,
  total_game_entries integer NOT NULL DEFAULT 0,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, snapshot_at)
);

CREATE TABLE IF NOT EXISTS public.psn_leaderboard_history (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rank integer NOT NULL,
  platinum_count bigint NOT NULL DEFAULT 0,
  total_games integer NOT NULL DEFAULT 0,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, snapshot_at)
);

CREATE TABLE IF NOT EXISTS public.xbox_leaderboard_history (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rank integer NOT NULL,
  gamerscore bigint NOT NULL DEFAULT 0,
  achievement_count integer NOT NULL DEFAULT 0,
  total_games integer NOT NULL DEFAULT 0,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, snapshot_at)
);

CREATE TABLE IF NOT EXISTS public.steam_leaderboard_history (
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  rank integer NOT NULL,
  achievement_count bigint NOT NULL DEFAULT 0,
  total_games integer NOT NULL DEFAULT 0,
  snapshot_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, snapshot_at)
);

CREATE INDEX IF NOT EXISTS idx_leaderboard_history_user_snapshot
  ON public.leaderboard_history(user_id, snapshot_at DESC);
CREATE INDEX IF NOT EXISTS idx_psn_leaderboard_history_user_snapshot
  ON public.psn_leaderboard_history(user_id, snapshot_at DESC);
CREATE INDEX IF NOT EXISTS idx_xbox_leaderboard_history_user_snapshot
  ON public.xbox_leaderboard_history(user_id, snapshot_at DESC);
CREATE INDEX IF NOT EXISTS idx_steam_leaderboard_history_user_snapshot
  ON public.steam_leaderboard_history(user_id, snapshot_at DESC);
