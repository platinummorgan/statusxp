BEGIN;
SET LOCAL lock_timeout='10s';
ALTER TABLE public.psn_sync_logs DROP CONSTRAINT psn_sync_logs_status_check;
ALTER TABLE public.psn_sync_logs ADD CONSTRAINT psn_sync_logs_status_check CHECK(status IN('pending','syncing','completed','failed','cancelled'));
ALTER TABLE public.xbox_sync_logs DROP CONSTRAINT xbox_sync_logs_status_check;
ALTER TABLE public.xbox_sync_logs ADD CONSTRAINT xbox_sync_logs_status_check CHECK(status IN('pending','syncing','completed','failed','cancelled'));
ALTER TABLE public.steam_sync_logs DROP CONSTRAINT steam_sync_logs_status_check;
ALTER TABLE public.steam_sync_logs ADD CONSTRAINT steam_sync_logs_status_check CHECK(status IN('pending','syncing','completed','failed','cancelled'));

CREATE OR REPLACE FUNCTION public.request_sync_cancellation(p_user_id uuid,p_platform text)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE current_status text; active boolean; result text;
BEGIN
 IF p_platform NOT IN('psn','xbox','steam') OR p_platform IS NULL THEN RAISE EXCEPTION 'Invalid platform'; END IF;
 EXECUTE format('SELECT %I FROM public.profiles_private WHERE id=$1 FOR UPDATE',p_platform||'_sync_status') INTO current_status USING p_user_id;
 IF current_status IS NULL AND NOT EXISTS(SELECT 1 FROM public.profiles_private WHERE id=p_user_id) THEN RAISE EXCEPTION 'Profile not found'; END IF;
 EXECUTE format('SELECT coalesce((SELECT status IN(''pending'',''syncing'') FROM public.%I WHERE user_id=$1 ORDER BY id DESC LIMIT 1),false)',p_platform||'_sync_logs') INTO active USING p_user_id;
 IF active OR current_status IN('pending','syncing','cancelling') THEN
  result:=CASE WHEN active THEN 'cancelling' ELSE 'stopped' END;
  EXECUTE format('UPDATE public.profiles_private SET %I=$2 WHERE id=$1',p_platform||'_sync_status') USING p_user_id,result;
 ELSE result:=coalesce(current_status,'stopped'); END IF;
 RETURN result;
END $$;

CREATE OR REPLACE FUNCTION public.finish_platform_sync(p_user_id uuid,p_platform text,p_log_id bigint,
 p_outcome text,p_games integer DEFAULT NULL,p_achievements integer DEFAULT NULL,p_error text DEFAULT NULL)
RETURNS text LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE profile_status text; log_status text; newer boolean; final_status text; message text; stamp timestamptz:=clock_timestamp();
BEGIN
 IF p_platform NOT IN('psn','xbox','steam') OR p_platform IS NULL OR p_outcome NOT IN('completed','failed','cancelled') OR p_outcome IS NULL
 OR p_games<0 OR p_achievements<0 THEN RAISE EXCEPTION 'Invalid sync outcome'; END IF;
 EXECUTE format('SELECT %I FROM public.profiles_private WHERE id=$1 FOR UPDATE',p_platform||'_sync_status') INTO profile_status USING p_user_id;
 IF NOT EXISTS(SELECT 1 FROM public.profiles_private WHERE id=p_user_id) THEN RAISE EXCEPTION 'Profile not found'; END IF;
 EXECUTE format('SELECT status FROM public.%I WHERE id=$1 AND user_id=$2 FOR UPDATE',p_platform||'_sync_logs') INTO log_status USING p_log_id,p_user_id;
 IF log_status IS NULL THEN RAISE EXCEPTION 'Sync log not found for this user'; END IF;
 IF log_status IN('completed','failed','cancelled') THEN RETURN log_status; END IF;
 EXECUTE format('SELECT EXISTS(SELECT 1 FROM public.%I WHERE user_id=$1 AND id>$2)',p_platform||'_sync_logs') INTO newer USING p_user_id,p_log_id;
 final_status:=CASE WHEN NOT newer AND profile_status='cancelling' THEN 'cancelled' ELSE p_outcome END;
 message:=CASE final_status WHEN 'cancelled' THEN 'Cancelled by user; saved progress retained'
 WHEN 'failed' THEN left(coalesce(p_error,'Sync failed'),500) ELSE NULL END;
 EXECUTE format('UPDATE public.%I SET status=$3,completed_at=$4,error_message=$5,games_processed=greatest(games_processed,$6),%I=greatest(%I,$7) WHERE id=$1 AND user_id=$2',
 p_platform||'_sync_logs',CASE WHEN p_platform='psn' THEN 'trophies_synced' ELSE 'achievements_synced' END,
 CASE WHEN p_platform='psn' THEN 'trophies_synced' ELSE 'achievements_synced' END)
 USING p_log_id,p_user_id,final_status,stamp,message,p_games,p_achievements;
 IF NOT newer THEN
  EXECUTE format('UPDATE public.profiles_private SET %I=$2,%I=$3,%I=$4,%I=CASE WHEN $5=''completed'' THEN $6 ELSE %I END WHERE id=$1',
  p_platform||'_sync_status',p_platform||'_sync_progress',p_platform||'_sync_error','last_'||p_platform||'_sync_at','last_'||p_platform||'_sync_at')
  USING p_user_id,CASE final_status WHEN 'completed' THEN 'success' WHEN 'cancelled' THEN 'stopped' ELSE 'error' END,
   CASE WHEN final_status='completed' THEN 100 ELSE 0 END,CASE WHEN final_status='failed' THEN message ELSE NULL END,final_status,stamp;
 END IF;
 RETURN final_status;
END $$;
REVOKE ALL ON FUNCTION public.request_sync_cancellation(uuid,text) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.finish_platform_sync(uuid,text,bigint,text,integer,integer,text) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.request_sync_cancellation(uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION public.finish_platform_sync(uuid,text,bigint,text,integer,integer,text) TO service_role;
-- Token refresh/startup may finish after a stop request. Preserve that request
-- until the worker reaches its cancellation checkpoint or final transaction.
CREATE OR REPLACE FUNCTION statusxp_private.preserve_sync_cancellation()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $$ BEGIN
 IF OLD.psn_sync_status='cancelling' AND NEW.psn_sync_status='syncing' THEN NEW.psn_sync_status:='cancelling'; END IF;
 IF OLD.xbox_sync_status='cancelling' AND NEW.xbox_sync_status='syncing' THEN NEW.xbox_sync_status:='cancelling'; END IF;
 IF OLD.steam_sync_status='cancelling' AND NEW.steam_sync_status='syncing' THEN NEW.steam_sync_status:='cancelling'; END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION statusxp_private.preserve_sync_cancellation() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER preserve_sync_cancellation BEFORE UPDATE ON public.profiles_private
FOR EACH ROW EXECUTE FUNCTION statusxp_private.preserve_sync_cancellation();
COMMIT;
