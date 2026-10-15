-- Keep client reads on the credential-masking profile view.
BEGIN;
ALTER POLICY "Anyone can view progress for leaderboard users"
ON public.user_progress USING (EXISTS (
 SELECT 1 FROM public.profiles p
 WHERE p.id = user_progress.user_id AND p.show_on_leaderboard = true
));
CREATE OR REPLACE VIEW public.steam_leaderboard_cache WITH (security_invoker=true) AS  SELECT up.user_id,
    COALESCE(p.steam_display_name, p.display_name, p.username, 'Player'::text) AS display_name,
    p.steam_avatar_url AS avatar_url,
    sum(GREATEST(COALESCE(up.achievements_earned, 0), 0))::integer AS achievement_count,
    sum(GREATEST(COALESCE(up.total_achievements, 0), 0))::integer AS potential_achievements,
    count(DISTINCT up.platform_game_id)::integer AS total_games,
    now() AS updated_at
   FROM user_progress up
     JOIN public.profiles p ON p.id = up.user_id
  WHERE up.platform_id = 4 AND COALESCE(up.achievements_earned, 0) > 0 AND p.show_on_leaderboard = true
  GROUP BY up.user_id, p.steam_display_name, p.display_name, p.username, p.steam_avatar_url;
CREATE OR REPLACE VIEW public.xbox_leaderboard_cache WITH (security_invoker=true) AS  WITH xbox_user_stats AS (
         SELECT up.user_id,
            sum(COALESCE(up.current_score, 0)) AS total_gamerscore,
            sum(
                CASE
                    WHEN COALESCE(up.metadata ->> 'max_gamerscore'::text, ''::text) ~ '^[0-9]+$'::text THEN (up.metadata ->> 'max_gamerscore'::text)::bigint
                    WHEN COALESCE(up.metadata ->> 'max_score'::text, ''::text) ~ '^[0-9]+$'::text THEN (up.metadata ->> 'max_score'::text)::bigint
                    ELSE 0::bigint
                END)::bigint AS potential_gamerscore,
            count(DISTINCT ROW(up.platform_id, up.platform_game_id)) AS total_games
           FROM user_progress up
          WHERE up.platform_id = ANY (ARRAY[10::bigint, 11::bigint, 12::bigint])
          GROUP BY up.user_id
        ), xbox_achievement_count AS (
         SELECT ua.user_id,
            count(*) AS achievement_count
           FROM public.user_achievement_unlocks ua
          WHERE ua.platform_id = ANY (ARRAY[10::bigint, 11::bigint, 12::bigint])
          GROUP BY ua.user_id
        )
 SELECT xus.user_id,
    COALESCE(p.xbox_gamertag, p.display_name, p.username, 'Player'::text) AS display_name,
    p.xbox_avatar_url AS avatar_url,
    COALESCE(xac.achievement_count, 0::bigint) AS achievement_count,
    xus.total_games,
    COALESCE(p.xbox_profile_gamerscore::bigint, xus.total_gamerscore, 0::bigint) AS gamerscore,
    COALESCE(xus.potential_gamerscore, 0::bigint) AS potential_gamerscore,
    now() AS updated_at
   FROM xbox_user_stats xus
     JOIN public.profiles p ON p.id = xus.user_id
     LEFT JOIN xbox_achievement_count xac ON xac.user_id = xus.user_id
  WHERE p.show_on_leaderboard = true
  ORDER BY (COALESCE(p.xbox_profile_gamerscore::bigint, xus.total_gamerscore, 0::bigint)) DESC, (COALESCE(xac.achievement_count, 0::bigint)) DESC, xus.total_games DESC;
NOTIFY pgrst, 'reload schema';
COMMIT;
