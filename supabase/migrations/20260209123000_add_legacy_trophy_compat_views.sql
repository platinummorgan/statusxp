-- Legacy compatibility layer for PS trophy model.
-- Non-destructive: maps legacy objects to current achievements schema.

BEGIN;
-- Legacy game_titles compatibility view
CREATE OR REPLACE VIEW "public"."game_titles" WITH ("security_invoker"='true') AS
SELECT
  ((('x'::text || "substr"("md5"(((g."platform_id")::text || '_'::text || g."platform_game_id")), 1, 15)))::bit(60))::bigint AS "id",
  g."platform_id",
  g."platform_game_id",
  g."name",
  g."cover_url",
  g."cover_url" AS "cover_image",
  NULL::text AS "proxied_cover_url",
  g."created_at",
  g."updated_at"
FROM "public"."games" g;
COMMENT ON VIEW "public"."game_titles" IS 'Legacy compatibility view over public.games using hashed game_title_id.';
-- Legacy trophies compatibility view (PS trophy-type achievements only)
CREATE OR REPLACE VIEW "public"."trophies" WITH ("security_invoker"='true') AS
SELECT
  ((('x'::text || "substr"("md5"((((a."platform_id")::text || '_'::text) || a."platform_game_id" || '_'::text || a."platform_achievement_id")), 1, 15)))::bit(60))::bigint AS "id",
  ((('x'::text || "substr"("md5"(((a."platform_id")::text || '_'::text || a."platform_game_id")), 1, 15)))::bit(60))::bigint AS "game_title_id",
  a."platform_id",
  a."platform_game_id",
  a."platform_achievement_id",
  a."name",
  COALESCE(a."description", ''::text) AS "description",
  LOWER(COALESCE((a."metadata" ->> 'psn_trophy_type'::text), 'bronze'::text)) AS "tier",
  a."icon_url",
  a."proxied_icon_url",
  a."rarity_global",
  COALESCE(((a."metadata" ->> 'hidden'::text))::boolean, false) AS "hidden",
  COALESCE(
    NULLIF((a."metadata" ->> 'sort_order'::text), ''::text)::integer,
    ROW_NUMBER() OVER (
      PARTITION BY a."platform_id", a."platform_game_id"
      ORDER BY
        CASE LOWER(COALESCE((a."metadata" ->> 'psn_trophy_type'::text), ''::text))
          WHEN 'platinum' THEN 1
          WHEN 'gold' THEN 2
          WHEN 'silver' THEN 3
          WHEN 'bronze' THEN 4
          ELSE 5
        END,
        a."name",
        a."platform_achievement_id"
    )
  ) AS "sort_order",
  a."created_at"
FROM "public"."achievements" a
WHERE LOWER(COALESCE((a."metadata" ->> 'psn_trophy_type'::text), ''::text)) IN ('bronze', 'silver', 'gold', 'platinum');
COMMENT ON VIEW "public"."trophies" IS 'Legacy compatibility view over public.achievements for PS trophy-tier records.';
-- Legacy user_trophies compatibility view
CREATE OR REPLACE VIEW "public"."user_trophies" WITH ("security_invoker"='true') AS
SELECT
  ((('x'::text || "substr"("md5"((((((ua."user_id")::text || '_'::text) || (ua."platform_id")::text) || '_'::text) || ua."platform_game_id" || '_'::text || ua."platform_achievement_id")), 1, 15)))::bit(60))::bigint AS "id",
  ua."user_id",
  ((('x'::text || "substr"("md5"((((ua."platform_id")::text || '_'::text) || ua."platform_game_id" || '_'::text || ua."platform_achievement_id")), 1, 15)))::bit(60))::bigint AS "trophy_id",
  ua."earned_at",
  ua."synced_at",
  ua."platform_id",
  ua."platform_game_id",
  ua."platform_achievement_id"
FROM "public"."user_achievements" ua
JOIN "public"."achievements" a
  ON a."platform_id" = ua."platform_id"
 AND a."platform_game_id" = ua."platform_game_id"
 AND a."platform_achievement_id" = ua."platform_achievement_id"
WHERE LOWER(COALESCE((a."metadata" ->> 'psn_trophy_type'::text), ''::text)) IN ('bronze', 'silver', 'gold', 'platinum');
COMMENT ON VIEW "public"."user_trophies" IS 'Legacy compatibility view over public.user_achievements joined to PS trophy-tier achievements.';
-- Write-through trigger functions for user_trophies view
CREATE OR REPLACE FUNCTION "public"."compat_user_trophies_insert"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_platform_id bigint;
  v_platform_game_id text;
  v_platform_achievement_id text;
BEGIN
  SELECT t."platform_id", t."platform_game_id", t."platform_achievement_id"
    INTO v_platform_id, v_platform_game_id, v_platform_achievement_id
  FROM "public"."trophies" t
  WHERE t."id" = NEW."trophy_id";

  IF v_platform_id IS NULL THEN
    RAISE EXCEPTION 'Unknown trophy_id: %', NEW."trophy_id";
  END IF;

  INSERT INTO "public"."user_achievements" (
    "user_id",
    "platform_id",
    "platform_game_id",
    "platform_achievement_id",
    "earned_at",
    "synced_at"
  ) VALUES (
    NEW."user_id",
    v_platform_id,
    v_platform_game_id,
    v_platform_achievement_id,
    COALESCE(NEW."earned_at", NOW()),
    COALESCE(NEW."synced_at", NOW())
  )
  ON CONFLICT ("user_id", "platform_id", "platform_game_id", "platform_achievement_id")
  DO UPDATE
  SET
    "earned_at" = EXCLUDED."earned_at",
    "synced_at" = COALESCE(EXCLUDED."synced_at", "public"."user_achievements"."synced_at");

  RETURN NEW;
END;
$$;
CREATE OR REPLACE FUNCTION "public"."compat_user_trophies_update"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_platform_id bigint;
  v_platform_game_id text;
  v_platform_achievement_id text;
BEGIN
  SELECT t."platform_id", t."platform_game_id", t."platform_achievement_id"
    INTO v_platform_id, v_platform_game_id, v_platform_achievement_id
  FROM "public"."trophies" t
  WHERE t."id" = COALESCE(NEW."trophy_id", OLD."trophy_id");

  IF v_platform_id IS NULL THEN
    RAISE EXCEPTION 'Unknown trophy_id: %', COALESCE(NEW."trophy_id", OLD."trophy_id");
  END IF;

  UPDATE "public"."user_achievements"
  SET
    "earned_at" = COALESCE(NEW."earned_at", "earned_at"),
    "synced_at" = COALESCE(NEW."synced_at", "synced_at")
  WHERE "user_id" = COALESCE(NEW."user_id", OLD."user_id")
    AND "platform_id" = v_platform_id
    AND "platform_game_id" = v_platform_game_id
    AND "platform_achievement_id" = v_platform_achievement_id;

  RETURN NEW;
END;
$$;
CREATE OR REPLACE FUNCTION "public"."compat_user_trophies_delete"()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_platform_id bigint;
  v_platform_game_id text;
  v_platform_achievement_id text;
BEGIN
  SELECT t."platform_id", t."platform_game_id", t."platform_achievement_id"
    INTO v_platform_id, v_platform_game_id, v_platform_achievement_id
  FROM "public"."trophies" t
  WHERE t."id" = OLD."trophy_id";

  IF v_platform_id IS NOT NULL THEN
    DELETE FROM "public"."user_achievements"
    WHERE "user_id" = OLD."user_id"
      AND "platform_id" = v_platform_id
      AND "platform_game_id" = v_platform_game_id
      AND "platform_achievement_id" = v_platform_achievement_id;
  END IF;

  RETURN OLD;
END;
$$;
DROP TRIGGER IF EXISTS "compat_user_trophies_insert_trg" ON "public"."user_trophies";
CREATE TRIGGER "compat_user_trophies_insert_trg"
INSTEAD OF INSERT ON "public"."user_trophies"
FOR EACH ROW EXECUTE FUNCTION "public"."compat_user_trophies_insert"();
DROP TRIGGER IF EXISTS "compat_user_trophies_update_trg" ON "public"."user_trophies";
CREATE TRIGGER "compat_user_trophies_update_trg"
INSTEAD OF UPDATE ON "public"."user_trophies"
FOR EACH ROW EXECUTE FUNCTION "public"."compat_user_trophies_update"();
DROP TRIGGER IF EXISTS "compat_user_trophies_delete_trg" ON "public"."user_trophies";
CREATE TRIGGER "compat_user_trophies_delete_trg"
INSTEAD OF DELETE ON "public"."user_trophies"
FOR EACH ROW EXECUTE FUNCTION "public"."compat_user_trophies_delete"();
GRANT SELECT ON TABLE "public"."game_titles" TO "anon", "authenticated", "service_role";
GRANT SELECT ON TABLE "public"."trophies" TO "anon", "authenticated", "service_role";
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE "public"."user_trophies" TO "authenticated", "service_role";
COMMIT;
