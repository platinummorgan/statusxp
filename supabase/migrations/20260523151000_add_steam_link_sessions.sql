-- Steam OpenID linking sessions
-- Stores short-lived CSRF state for Steam account linking

CREATE TABLE IF NOT EXISTS public.steam_link_sessions (
  state text PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  return_to text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  consumed_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_steam_link_sessions_user_id
  ON public.steam_link_sessions(user_id);

CREATE INDEX IF NOT EXISTS idx_steam_link_sessions_expires_at
  ON public.steam_link_sessions(expires_at);

ALTER TABLE public.steam_link_sessions ENABLE ROW LEVEL SECURITY;

COMMENT ON TABLE public.steam_link_sessions IS
  'Temporary sessions used to validate Steam OpenID account-link callbacks.';
