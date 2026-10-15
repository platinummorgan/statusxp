-- Public source excludes account-specific recovery data; original retained in private audit archive.
BEGIN;
CREATE TABLE statusxp_private.xbox_import_reviews (
 user_id uuid NOT NULL REFERENCES public.profiles_private(id) ON DELETE CASCADE,
 platform_id bigint NOT NULL,platform_game_id text NOT NULL,observed_xuid text NOT NULL,
 review_status text NOT NULL CHECK(review_status IN('needs_reauthorization','title_missing_from_current_history')),
 evidence jsonb NOT NULL,observed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(user_id,platform_id,platform_game_id)
);
REVOKE ALL ON statusxp_private.xbox_import_reviews FROM PUBLIC,anon,authenticated;
-- One-time account-specific data was applied privately in production.

-- Observed account identity is review evidence, not attribution of old stats.
UPDATE public.user_progress up SET metadata=coalesce(up.metadata,'{}'::jsonb)||jsonb_build_object(
 'xbox_account_review_status',r.review_status,'xbox_account_reviewed_at',r.observed_at)
FROM statusxp_private.xbox_import_reviews r JOIN public.profiles_private p ON p.id=r.user_id
WHERE up.user_id=r.user_id AND up.platform_id=r.platform_id AND up.platform_game_id=r.platform_game_id
 AND p.xbox_xuid=r.observed_xuid AND p.xbox_sync_status NOT IN('syncing','cancelling')
 AND up.achievements_earned>(SELECT count(*) FROM public.user_achievement_unlocks u WHERE u.user_id=up.user_id AND u.platform_id=up.platform_id AND u.platform_game_id=up.platform_game_id);
COMMIT;
