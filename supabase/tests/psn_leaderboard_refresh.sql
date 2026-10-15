-- Rollback-only regression fixture for the PSN cache projection.
BEGIN;
CREATE TEMP TABLE test_profiles(id uuid,psn_online_id text,display_name text,username text,psn_avatar_url text,show_on_leaderboard boolean,merged_into_user_id uuid);
CREATE TEMP TABLE test_achievements(platform_id bigint,platform_game_id text,platform_achievement_id text,is_platinum boolean,metadata jsonb);
CREATE TEMP TABLE test_user_achievements(user_id uuid,platform_id bigint,platform_game_id text,platform_achievement_id text);
INSERT INTO test_profiles(id,show_on_leaderboard,merged_into_user_id) VALUES
 ('00000000-0000-0000-0000-000000000001',true,NULL),
 ('00000000-0000-0000-0000-000000000002',true,NULL),
 ('00000000-0000-0000-0000-000000000003',false,NULL),
 ('00000000-0000-0000-0000-000000000004',true,'00000000-0000-0000-0000-000000000001'),
 ('00000000-0000-0000-0000-000000000005',true,NULL),
 ('00000000-0000-0000-0000-000000000006',true,NULL);
INSERT INTO test_achievements VALUES
 (1,'shared','b1',false,'{"psn_trophy_type":"bronze"}'),
 (1,'shared','b2',false,'{"psn_trophy_type":"bronze"}'),
 (1,'shared','p',false,'{"psn_trophy_type":"platinum"}'),
 (2,'shared','s',false,'{"psn_trophy_type":"silver"}'),
 (2,'shared','bad',false,'{"gamerscore":50}'),
 (3,'xbox','x',false,'{"psn_trophy_type":"gold"}');
INSERT INTO test_user_achievements VALUES
 ('00000000-0000-0000-0000-000000000001',1,'shared','b1'),
 ('00000000-0000-0000-0000-000000000001',1,'shared','b2'),
 ('00000000-0000-0000-0000-000000000001',1,'shared','p'),
 ('00000000-0000-0000-0000-000000000001',2,'shared','s'),
 ('00000000-0000-0000-0000-000000000001',2,'shared','bad'),
 ('00000000-0000-0000-0000-000000000002',2,'shared','bad'),
 ('00000000-0000-0000-0000-000000000003',1,'shared','b1'),
 ('00000000-0000-0000-0000-000000000004',1,'shared','b1'),
 ('00000000-0000-0000-0000-000000000005',2,'shared','s'),
 ('00000000-0000-0000-0000-000000000006',3,'xbox','x');
CREATE TEMP TABLE test_result AS
WITH valid_definitions AS MATERIALIZED (
 SELECT platform_id,platform_game_id,platform_achievement_id,
 CASE WHEN is_platinum OR metadata->>'psn_trophy_type'='platinum' THEN 'platinum' ELSE metadata->>'psn_trophy_type' END trophy_type
 FROM pg_temp.test_achievements
 WHERE platform_id IN(1,2,5,9) AND (is_platinum OR metadata->>'psn_trophy_type' IN('bronze','silver','gold','platinum'))
), earned AS (
 SELECT ua.user_id,count(*) FILTER(WHERE a.trophy_type='bronze') bronze_count,
 count(*) FILTER(WHERE a.trophy_type='silver') silver_count,count(*) FILTER(WHERE a.trophy_type='gold') gold_count,
 count(*) FILTER(WHERE a.trophy_type='platinum') platinum_count,count(*) total_trophies,
 count(DISTINCT (ua.platform_id,ua.platform_game_id)) total_games
 FROM pg_temp.test_user_achievements ua JOIN valid_definitions a USING(platform_id,platform_game_id,platform_achievement_id)
 JOIN pg_temp.test_profiles p ON p.id=ua.user_id AND p.show_on_leaderboard AND p.merged_into_user_id IS NULL
 WHERE ua.platform_id IN(1,2,5,9) GROUP BY ua.user_id
), game_possible AS MATERIALIZED (
 SELECT platform_id,platform_game_id,count(*) FILTER(WHERE trophy_type='bronze') possible_bronze,
 count(*) FILTER(WHERE trophy_type='silver') possible_silver,count(*) FILTER(WHERE trophy_type='gold') possible_gold,
 count(*) FILTER(WHERE trophy_type='platinum') possible_platinum
 FROM valid_definitions GROUP BY platform_id,platform_game_id
), possible AS (
 SELECT ug.user_id,sum(g.possible_bronze)::bigint possible_bronze,sum(g.possible_silver)::bigint possible_silver,
 sum(g.possible_gold)::bigint possible_gold,sum(g.possible_platinum)::bigint possible_platinum
 FROM (SELECT DISTINCT user_id,platform_id,platform_game_id FROM pg_temp.test_user_achievements WHERE platform_id IN(1,2,5,9)) ug
 JOIN game_possible g USING(platform_id,platform_game_id) GROUP BY ug.user_id
)
SELECT e.user_id,COALESCE(p.psn_online_id,p.display_name,p.username,'Player') display_name,p.psn_avatar_url avatar_url,
 e.bronze_count,e.silver_count,e.gold_count,e.platinum_count,
 COALESCE(t.possible_bronze,0)::bigint possible_bronze,COALESCE(t.possible_silver,0)::bigint possible_silver,
 COALESCE(t.possible_gold,0)::bigint possible_gold,COALESCE(t.possible_platinum,0)::bigint possible_platinum,
 e.total_trophies,e.total_games,now() updated_at
 FROM earned e JOIN pg_temp.test_profiles p ON p.id=e.user_id LEFT JOIN possible t ON t.user_id=e.user_id
 WHERE e.total_trophies>0
 ORDER BY e.platinum_count DESC,e.gold_count DESC,e.silver_count DESC,e.bronze_count DESC,e.user_id
;
DO $$
BEGIN
 ASSERT (SELECT count(*)=2 FROM test_result), 'Only visible, unmerged users with genuine PSN trophies qualify';
 ASSERT (SELECT total_trophies=4 AND bronze_count=2 AND silver_count=1 AND platinum_count=1 AND total_games=2
  FROM test_result WHERE user_id='00000000-0000-0000-0000-000000000001'), 'Count recognized trophies and distinct platform/game pairs';
 ASSERT (SELECT possible_bronze=2 AND possible_silver=1 AND possible_platinum=1
  FROM test_result WHERE user_id='00000000-0000-0000-0000-000000000001'), 'Possible counts must not multiply with earned trophies';
 ASSERT (SELECT platinum_count=0 AND silver_count=1 FROM test_result WHERE user_id='00000000-0000-0000-0000-000000000005'), 'A player needs a trophy, not necessarily a platinum';
 ASSERT NOT EXISTS(SELECT 1 FROM test_result WHERE total_trophies<>bronze_count+silver_count+gold_count+platinum_count), 'Displayed counts must agree with trophy total';
END $$;
SELECT 'PSN leaderboard regression assertions passed' result;
ROLLBACK;
