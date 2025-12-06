-- Migration: 008_update_sync_rate_limit_function.sql
-- Created: 2025-12-02
-- Description: Update rate limit function to improve first-sync messaging

-- ============================================================================
-- Update helper function to better communicate first-time sync
-- ============================================================================
create or replace function can_user_sync_psn(user_id uuid)
returns table (
  can_sync boolean,
  reason text,
  next_sync_available_at timestamptz
) as $$
declare
  v_subscription_tier text;
  v_last_sync_at timestamptz;
  v_sync_cooldown interval;
  v_next_available timestamptz;
begin
  -- Get user's subscription tier and last sync time
  select 
    subscription_tier,
    last_psn_sync_at
  into 
    v_subscription_tier,
    v_last_sync_at
  from profiles
  where id = user_id;

  -- If never synced, always allow (first-time sync is free)
  if v_last_sync_at is null then
    return query select true, 'First sync - no cooldown'::text, null::timestamptz;
    return;
  end if;

  -- Determine cooldown based on subscription tier
  v_sync_cooldown := case 
    when v_subscription_tier = 'premium' then interval '8 hours'
    else interval '24 hours'
  end;

  -- Calculate when next sync is available
  v_next_available := v_last_sync_at + v_sync_cooldown;

  -- Check if cooldown has passed
  if now() >= v_next_available then
    return query select true, 'Cooldown expired'::text, null::timestamptz;
  else
    return query select 
      false, 
      format('Sync cooldown active. %s users can sync every %s', 
        initcap(v_subscription_tier), 
        case 
          when v_subscription_tier = 'premium' then '8 hours'
          else '24 hours'
        end
      )::text,
      v_next_available;
  end if;
end;
$$ language plpgsql security definer;
