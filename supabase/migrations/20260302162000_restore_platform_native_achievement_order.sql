-- Restore platform-native achievement ordering for per-game lists.
-- PSN: base group first, then native trophy sequence (sort_order or trophy id).
-- Xbox: native sequence (display_order or achievement id).
-- Others (e.g., Steam): native sequence when available, otherwise stable fallback.
create or replace function public.get_user_achievements_for_game(
  p_user_id uuid,
  p_platform_id bigint,
  p_platform_game_id text,
  p_search_query text default null::text
)
returns table(
  platform_achievement_id text,
  achievement_name text,
  game_name text,
  cover_url text,
  icon_url text,
  rarity_global numeric,
  earned_at timestamp with time zone
)
language plpgsql
security definer
as $$
begin
  return query
  select
    a.platform_achievement_id,
    a.name as achievement_name,
    g.name as game_name,
    g.cover_url,
    a.icon_url,
    a.rarity_global,
    ua.earned_at
  from user_achievements ua
  inner join achievements a
    on a.platform_id = ua.platform_id
   and a.platform_game_id = ua.platform_game_id
   and a.platform_achievement_id = ua.platform_achievement_id
  inner join games g
    on g.platform_id = ua.platform_id
   and g.platform_game_id = ua.platform_game_id
  where ua.user_id = p_user_id
    and ua.platform_id = p_platform_id
    and ua.platform_game_id = p_platform_game_id
    and (p_search_query is null or a.name ilike '%' || p_search_query || '%')
  order by
    case
      when p_platform_id in (1, 2, 5, 9) then
        case when coalesce(a.metadata->>'trophy_group_id', 'default') = 'default' then 0 else 1 end
      else 0
    end asc,
    case
      when p_platform_id in (1, 2, 5, 9) then
        case
          when coalesce(a.metadata->>'sort_order', '') ~ '^[0-9]+$' then (a.metadata->>'sort_order')::bigint
          when a.platform_achievement_id ~ '^[0-9]+$' then a.platform_achievement_id::bigint
          else 9223372036854775807
        end
      else 9223372036854775807
    end asc,
    case
      when p_platform_id between 10 and 12 then
        case
          when coalesce(a.metadata->>'display_order', '') ~ '^[0-9]+$' then (a.metadata->>'display_order')::bigint
          when a.platform_achievement_id ~ '^[0-9]+$' then a.platform_achievement_id::bigint
          else 9223372036854775807
        end
      else 9223372036854775807
    end asc,
    case
      when p_platform_id not in (1, 2, 5, 9) and p_platform_id not between 10 and 12 then
        case
          when coalesce(a.metadata->>'steam_display_order', '') ~ '^[0-9]+$' then (a.metadata->>'steam_display_order')::bigint
          when coalesce(a.metadata->>'sort_order', '') ~ '^[0-9]+$' then (a.metadata->>'sort_order')::bigint
          else 9223372036854775807
        end
      else 9223372036854775807
    end asc,
    a.name asc,
    ua.earned_at desc;
end;
$$;

