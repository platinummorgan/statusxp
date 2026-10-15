BEGIN;
DO $$ DECLARE n integer; BEGIN
 SELECT count(*) INTO n FROM achievements WHERE platform_id=12 AND platform_game_id='1046363979';
 ASSERT n>0, 'Guard fixture must exist';
 BEGIN
 UPDATE achievements SET platform_id=2 WHERE (platform_id,platform_game_id,platform_achievement_id) IN
 (SELECT platform_id,platform_game_id,platform_achievement_id FROM achievements WHERE platform_id=12 AND platform_game_id='1046363979' LIMIT 1);
 RAISE EXCEPTION 'Guard allowed Xbox metadata in PSN';
 EXCEPTION WHEN check_violation THEN NULL;
 END;
END $$;
ROLLBACK;
