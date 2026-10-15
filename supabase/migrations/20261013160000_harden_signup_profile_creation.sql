BEGIN;
SET LOCAL lock_timeout='10s';
-- Shared by the signup trigger and the reviewed historical repair. Serialize
-- repairs of the same auth account and resolve usernames via the unique index.
CREATE OR REPLACE FUNCTION statusxp_private.ensure_auth_profile(p_user_id uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE account auth.users%ROWTYPE; base_name text; candidate text; attempt integer:=0; inserted uuid;
BEGIN
 SELECT * INTO account FROM auth.users WHERE id=p_user_id FOR UPDATE;
 IF NOT FOUND OR account.deleted_at IS NOT NULL THEN RETURN false; END IF;
 IF EXISTS(SELECT 1 FROM public.profiles_private WHERE id=p_user_id) THEN RETURN false; END IF;
 base_name:=left(coalesce(nullif(btrim(account.raw_user_meta_data->>'display_name'),''),
  nullif(btrim(account.raw_user_meta_data->>'full_name'),''),
  nullif(btrim(account.raw_user_meta_data->>'name'),''),
  nullif(split_part(account.email,'@',1),''),'Player'),64);
 LOOP
  candidate:=CASE attempt WHEN 0 THEN base_name
   WHEN 1 THEN base_name||'_'||left(replace(p_user_id::text,'-',''),8)
   WHEN 2 THEN base_name||'_'||replace(p_user_id::text,'-','')
   ELSE base_name||'_'||replace(p_user_id::text,'-','')||'_'||attempt::text END;
  INSERT INTO public.profiles_private(id,username,created_at,updated_at,psn_sync_status,xbox_sync_status,steam_sync_status)
  VALUES(p_user_id,candidate,coalesce(account.created_at,now()),now(),'never_synced','never_synced','never_synced')
  ON CONFLICT DO NOTHING RETURNING id INTO inserted;
  IF inserted IS NOT NULL THEN RETURN true; END IF;
  IF EXISTS(SELECT 1 FROM public.profiles_private WHERE id=p_user_id) THEN RETURN false; END IF;
  attempt:=attempt+1;
  IF attempt>100 THEN RAISE EXCEPTION 'Could not allocate a unique profile username'; END IF;
 END LOOP;
END $$;
REVOKE ALL ON FUNCTION statusxp_private.ensure_auth_profile(uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$ BEGIN
 PERFORM statusxp_private.ensure_auth_profile(NEW.id);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC,anon,authenticated;
COMMIT;
