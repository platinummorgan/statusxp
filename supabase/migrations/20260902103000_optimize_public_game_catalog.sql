-- Keep public catalog paging and substring search below the API statement timeout.
CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA extensions;

CREATE INDEX IF NOT EXISTS idx_games_name_trgm
  ON public.games
  USING gin (name extensions.gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_games_platform_name
  ON public.games (platform_id, name, platform_game_id);
