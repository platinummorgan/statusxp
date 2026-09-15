-- Canonical achievement comments use the platform-scoped composite foreign key.
-- Keep the legacy integer column for old clients while allowing new clients to
-- write without inventing an invalid numeric identifier.
ALTER TABLE public.achievement_comments
  ALTER COLUMN achievement_id DROP NOT NULL;

COMMENT ON COLUMN public.achievement_comments.achievement_id IS
  'DEPRECATED compatibility value for legacy clients. New writes identify achievements with (platform_id, platform_game_id, platform_achievement_id).';
