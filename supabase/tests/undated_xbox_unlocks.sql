BEGIN;
SET LOCAL statement_timeout='60s';
INSERT INTO auth.users(id,email,raw_user_meta_data) VALUES
 ('00000000-0000-4000-8000-000000009957','undated-9957@statusxp.invalid','{}'),
 ('00000000-0000-4000-8000-000000009958','undated-9958@statusxp.invalid','{}');
INSERT INTO games(platform_id,platform_game_id,name) VALUES(10,'undated-9957','Undated fixture');
INSERT INTO achievements(platform_id,platform_game_id,platform_achievement_id,name,rarity_global,include_in_score)
VALUES(10,'undated-9957','1','Unknown date',0,true),(10,'undated-9957','2','Known date',NULL,true);
INSERT INTO user_undated_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,evidence_source)
VALUES('00000000-0000-4000-8000-000000009957',10,'undated-9957','1','xbox_live');
INSERT INTO user_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,earned_at)
VALUES('00000000-0000-4000-8000-000000009957',10,'undated-9957','2','2025-01-01T00:00:00Z');
-- Even a later redundant undated confirmation cannot count a dated unlock twice.
INSERT INTO user_undated_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,evidence_source)
VALUES('00000000-0000-4000-8000-000000009957',10,'undated-9957','2','openxbl');
SELECT refresh_statusxp_leaderboard_for_user('00000000-0000-4000-8000-000000009957');
INSERT INTO user_progress(user_id,platform_id,platform_game_id,achievements_earned,total_achievements,completion_percentage)
VALUES('00000000-0000-4000-8000-000000009957',10,'undated-9957',2,2,100);
DO $$ BEGIN
 ASSERT (SELECT count(*)=2 FROM user_achievement_unlocks WHERE user_id='00000000-0000-4000-8000-000000009957');
 ASSERT (SELECT count(*)=1 FROM user_achievements WHERE user_id='00000000-0000-4000-8000-000000009957'),'Installed date-based APIs retain only known dates';
 ASSERT (SELECT earned_at IS NULL AND NOT earned_date_known FROM user_achievement_unlocks WHERE user_id='00000000-0000-4000-8000-000000009957' AND platform_achievement_id='1');
 ASSERT (SELECT total_statusxp=13 AND total_game_entries=1 FROM leaderboard_cache WHERE user_id='00000000-0000-4000-8000-000000009957'),'Unknown dates still contribute XP with per-game rounding';
 ASSERT (SELECT total_statusxp=13 FROM statusxp_private.statusxp_refresh_totals WHERE user_id='00000000-0000-4000-8000-000000009957'),'Full and per-user score sources must agree';
 ASSERT (SELECT sum(total_statusxp)=13 FROM get_user_grouped_games('00000000-0000-4000-8000-000000009957')),'Game library must include confirmed undated XP';
END $$;
INSERT INTO games(platform_id,platform_game_id,name) VALUES(4,'undated-9957-steam','Steam stats fixture');
INSERT INTO user_progress(user_id,platform_id,platform_game_id,achievements_earned,total_achievements) VALUES('00000000-0000-4000-8000-000000009957',4,'undated-9957-steam',3,5);
UPDATE profiles_private SET show_on_leaderboard=false WHERE id='00000000-0000-4000-8000-000000009957';
SELECT set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000009957","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 ASSERT (SELECT count(*)=2 FROM user_achievement_unlocks WHERE user_id='00000000-0000-4000-8000-000000009957'),'Owner can read hidden profile unlocks';
 ASSERT (SELECT count(*)=2 FROM user_progress WHERE user_id=auth.uid()),'Owner progress reads must work through the safe profile view';
 ASSERT (SELECT count(*)=2 FROM get_user_grouped_games(auth.uid())),'Owner library RPC must run with client privileges';
 ASSERT NOT has_table_privilege('authenticated','public.profiles_private','SELECT'),'Credentials stay private';
 ASSERT (SELECT sum(statusxp_effective)=13 FROM calculate_statusxp_with_stacks('00000000-0000-4000-8000-000000009957'));
 BEGIN
  INSERT INTO user_undated_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,evidence_source)
  VALUES('00000000-0000-4000-8000-000000009957',10,'undated-9957','1','openxbl');
  RAISE EXCEPTION 'Client forged an unlock';
 EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END $$;
SET LOCAL ROLE postgres;
SELECT set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000009958","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 ASSERT NOT EXISTS(SELECT 1 FROM user_progress WHERE user_id='00000000-0000-4000-8000-000000009957'),'Other users cannot read hidden progress';
 ASSERT NOT EXISTS(SELECT 1 FROM get_user_grouped_games('00000000-0000-4000-8000-000000009957')),'Hidden game library remains private';
 ASSERT NOT EXISTS(SELECT 1 FROM user_achievement_unlocks WHERE user_id='00000000-0000-4000-8000-000000009957'),'Other users cannot read hidden unlocks'; END $$;
SET LOCAL ROLE postgres;
UPDATE profiles_private SET show_on_leaderboard=true WHERE id='00000000-0000-4000-8000-000000009957';
SET LOCAL ROLE anon;
DO $$ BEGIN ASSERT (SELECT count(*)=2 FROM user_achievement_unlocks WHERE user_id='00000000-0000-4000-8000-000000009957'),'Public profiles retain public achievement visibility';
 ASSERT (SELECT count(*)=2 FROM get_user_grouped_games('00000000-0000-4000-8000-000000009957')),'Public library reads retain client access';
 ASSERT (SELECT achievement_count=2 FROM xbox_leaderboard_cache WHERE user_id='00000000-0000-4000-8000-000000009957'),'Xbox stats include dated and undated unlocks';
 ASSERT (SELECT achievement_count=3 FROM steam_leaderboard_cache WHERE user_id='00000000-0000-4000-8000-000000009957'),'Steam stats remain readable';
 END $$;
SET LOCAL ROLE postgres;
INSERT INTO user_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,earned_at)
VALUES('00000000-0000-4000-8000-000000009957',10,'undated-9957','1','2024-05-01T00:00:00Z');
DO $$ BEGIN
 ASSERT NOT EXISTS(SELECT 1 FROM user_undated_achievements WHERE user_id='00000000-0000-4000-8000-000000009957' AND platform_achievement_id='1'),'Real date promotes and removes undated record';
 ASSERT (SELECT count(*)=2 FROM user_achievement_unlocks WHERE user_id='00000000-0000-4000-8000-000000009957');
 ASSERT (SELECT bool_and(earned_date_known) FROM user_achievement_unlocks WHERE user_id='00000000-0000-4000-8000-000000009957');
END $$;
INSERT INTO games(platform_id,platform_game_id,name) VALUES(10,'undated-9957-only','Only undated fixture');
INSERT INTO achievements(platform_id,platform_game_id,platform_achievement_id,name,include_in_score)
VALUES(10,'undated-9957-only','1','Unknown time',true);
INSERT INTO user_undated_achievements(user_id,platform_id,platform_game_id,platform_achievement_id,evidence_source)
VALUES('00000000-0000-4000-8000-000000009957',10,'undated-9957-only','1','xbox_live');
INSERT INTO user_progress(user_id,platform_id,platform_game_id,achievements_earned,total_achievements,last_played_at)
VALUES('00000000-0000-4000-8000-000000009957',10,'undated-9957-only',1,1,'2025-01-05T00:00:00Z');
DO $$ BEGIN
 ASSERT (SELECT (platforms[1]->>'last_trophy_earned_at') IS NULL FROM get_user_grouped_games('00000000-0000-4000-8000-000000009957') WHERE name='Only undated fixture'),'Last played cannot be substituted for an unknown unlock date';
END $$;
ROLLBACK;
