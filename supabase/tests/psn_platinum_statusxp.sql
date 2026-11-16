BEGIN;
SET LOCAL statement_timeout = '120s';

INSERT INTO auth.users(id, email, raw_user_meta_data)
VALUES (
  '00000000-0000-4000-8000-000000011515',
  'platinum-score-11515@statusxp.invalid',
  '{"display_name":"Platinum scoring fixture"}'
);
UPDATE public.profiles_private SET show_on_leaderboard = true
WHERE id = '00000000-0000-4000-8000-000000011515';

INSERT INTO public.games(platform_id, platform_game_id, name) VALUES
  (1, 'platinum-score-11515-main', 'Platinum scoring fixture'),
  (2, 'platinum-score-11515-ps4', 'PS4 fixture'),
  (5, 'platinum-score-11515-ps3', 'PS3 fixture'),
  (9, 'platinum-score-11515-vita', 'Vita fixture'),
  (4, 'platinum-score-11515-steam', 'Steam fixture');

INSERT INTO public.achievements(
  platform_id, platform_game_id, platform_achievement_id, name,
  rarity_global, base_status_xp, rarity_multiplier, is_platinum, include_in_score, metadata
) VALUES
  (1, 'platinum-score-11515-main', '0', 'Native Platinum',
    0.1, 0, 0, true, false, '{"psn_trophy_type":"platinum"}'),
  (1, 'platinum-score-11515-main', '1', 'Ordinary earned trophy',
    50, 0, 1, false, true, '{"psn_trophy_type":"bronze"}'),
  (1, 'platinum-score-11515-main', '2', 'Unearned trophy',
    0, 0, 1, false, true, '{"psn_trophy_type":"gold"}'),
  (1, 'platinum-score-11515-main', '3', 'Explicitly excluded ordinary trophy',
    0, 12, 1, false, false, '{"psn_trophy_type":"gold"}'),
  (2, 'platinum-score-11515-ps4', '0', 'Metadata-only Platinum',
    0.2, 0, 0, false, false, '{"psn_trophy_type":"platinum"}'),
  (5, 'platinum-score-11515-ps3', '0', 'Flag-only Platinum',
    50, 0, 0, true, false, '{}'),
  (9, 'platinum-score-11515-vita', '0', 'Unknown-rarity Platinum',
    NULL, 0, 0, true, false, '{"psn_trophy_type":"platinum"}'),
  (4, 'platinum-score-11515-steam', '0', 'Non-PSN excluded definition',
    0, 12, 1, true, false, '{}');

DO $$
BEGIN
  ASSERT (SELECT include_in_score AND is_platinum AND base_status_xp = 57.83
      AND rarity_multiplier = 1
    FROM public.achievements
    WHERE platform_id = 1 AND platform_game_id = 'platinum-score-11515-main'
      AND platform_achievement_id = '0'), 'Legacy PSN inserts must score native Platinums';
  ASSERT (SELECT include_in_score AND is_platinum AND base_status_xp = 57.66
    FROM public.achievements
    WHERE platform_id = 2 AND platform_game_id = 'platinum-score-11515-ps4'),
    'Metadata-only Platinums must preserve their type and score';
  ASSERT (SELECT include_in_score AND base_status_xp = 7.69
    FROM public.achievements
    WHERE platform_id = 5 AND platform_game_id = 'platinum-score-11515-ps3'),
    'Flag-only Platinums must score on legacy PSN platforms';
  ASSERT (SELECT include_in_score AND base_status_xp = 0.5
    FROM public.achievements
    WHERE platform_id = 9 AND platform_game_id = 'platinum-score-11515-vita'),
    'Unknown rarity must use the existing common-trophy default';
  ASSERT (SELECT base_status_xp = 1.94 FROM public.achievements
    WHERE platform_id = 1 AND platform_game_id = 'platinum-score-11515-main'
      AND platform_achievement_id = '1'), 'Ordinary earned trophies retain their curve';
  ASSERT (SELECT base_status_xp = 12 FROM public.achievements
    WHERE platform_id = 1 AND platform_game_id = 'platinum-score-11515-main'
      AND platform_achievement_id = '2'), 'Ordinary rare trophies retain the 12 XP cap';
  ASSERT (SELECT NOT include_in_score AND base_status_xp = 0
    FROM public.achievements
    WHERE platform_id = 4 AND platform_game_id = 'platinum-score-11515-steam'),
    'Platinum enforcement must be scoped to PSN platforms';
  ASSERT (SELECT NOT include_in_score AND base_status_xp = 0
    FROM public.achievements
    WHERE platform_id = 1 AND platform_game_id = 'platinum-score-11515-main'
      AND platform_achievement_id = '3'), 'Ordinary exclusion rules must be preserved';
END;
$$;

-- Simulate an old sync overwriting the flags while refreshing native rarity.
UPDATE public.achievements
SET rarity_global = 0.2, include_in_score = false, base_status_xp = 0, rarity_multiplier = 0
WHERE platform_id = 1 AND platform_game_id = 'platinum-score-11515-main'
  AND platform_achievement_id = '0';

DO $$
BEGIN
  ASSERT (SELECT include_in_score AND base_status_xp = 57.66 AND rarity_multiplier = 1
    FROM public.achievements
    WHERE platform_id = 1 AND platform_game_id = 'platinum-score-11515-main'
      AND platform_achievement_id = '0'), 'Subsequent syncs must retain Platinum scoring';
END;
$$;

INSERT INTO public.user_achievements(
  user_id, platform_id, platform_game_id, platform_achievement_id, earned_at
) VALUES
  ('00000000-0000-4000-8000-000000011515', 1, 'platinum-score-11515-main', '0', now()),
  ('00000000-0000-4000-8000-000000011515', 1, 'platinum-score-11515-main', '1', now()),
  ('00000000-0000-4000-8000-000000011515', 1, 'platinum-score-11515-main', '3', now());

SELECT public.refresh_statusxp_leaderboard_for_user('00000000-0000-4000-8000-000000011515');
DO $$
BEGIN
  ASSERT (SELECT total_statusxp = 60 AND potential_statusxp = 72 AND total_game_entries = 1
    FROM public.leaderboard_cache
    WHERE user_id = '00000000-0000-4000-8000-000000011515'),
    'Per-user refresh must count earned Platinum XP once and include unearned potential separately';
  ASSERT (SELECT sum(statusxp_effective) = 60
    FROM public.calculate_statusxp_with_stacks('00000000-0000-4000-8000-000000011515')),
    'Canonical scoring must round the complete earned game total';
END;
$$;

SELECT public.refresh_statusxp_leaderboard();
DO $$
BEGIN
  ASSERT (SELECT total_statusxp = 60 AND potential_statusxp = 72 AND total_game_entries = 1
    FROM public.leaderboard_cache
    WHERE user_id = '00000000-0000-4000-8000-000000011515'),
    'Full refresh must agree with the per-user refresh';
END;
$$;

SELECT 'PSN Platinum scoring regression assertions passed' AS result;
ROLLBACK;
