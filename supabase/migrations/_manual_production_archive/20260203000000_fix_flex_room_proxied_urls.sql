-- Fix flex room RPC functions to return proxied URLs for CORS-free image loading

-- Update get_rarest_achievement_v2
CREATE OR REPLACE FUNCTION public.get_rarest_achievement_v2(p_user_id uuid)
RETURNS TABLE(
  platform_id bigint,
  platform_game_id text,
  platform_achievement_id text,
  earned_at timestamp with time zone,
  rarity_global numeric,
  achievement_name text,
  achievement_icon_url text,
  game_name text,
  game_cover_url text
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    a.name as achievement_name,
    COALESCE(a.proxied_icon_url, a.icon_url) as achievement_icon_url,
    gt.name as game_name,
    COALESCE(gt.proxied_cover_url, gt.cover_url) as game_cover_url
  FROM user_achievements ua
  JOIN achievements a ON 
    ua.platform_id = a.platform_id 
    AND ua.platform_game_id = a.platform_game_id 
    AND ua.platform_achievement_id = a.platform_achievement_id
  JOIN game_titles gt ON 
    ua.platform_id = gt.platform_id 
    AND ua.platform_game_id = gt.platform_game_id
  WHERE ua.user_id = p_user_id
    AND ua.earned_at IS NOT NULL
    AND a.rarity_global IS NOT NULL
  ORDER BY a.rarity_global ASC
  LIMIT 1;
END;
$$;

-- Update get_most_time_sunk_game_v2
CREATE OR REPLACE FUNCTION public.get_most_time_sunk_game_v2(p_user_id uuid)
RETURNS TABLE(
  platform_id bigint,
  platform_game_id text,
  platform_achievement_id text,
  earned_at timestamp with time zone,
  rarity_global numeric,
  achievement_name text,
  achievement_icon_url text,
  game_name text,
  game_cover_url text
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  WITH game_completion AS (
    SELECT 
      gt.platform_id,
      gt.platform_game_id,
      gt.name as game_name,
      COALESCE(gt.proxied_cover_url, gt.cover_url) as game_cover_url,
      COUNT(ua.platform_achievement_id) as earned_count,
      (SELECT COUNT(*) FROM achievements a2 
       WHERE a2.platform_id = gt.platform_id 
       AND a2.platform_game_id = gt.platform_game_id) as total_count,
      MAX(ua.earned_at) as latest_earned
    FROM game_titles gt
    JOIN user_achievements ua ON 
      gt.platform_id = ua.platform_id 
      AND gt.platform_game_id = ua.platform_game_id
    WHERE ua.user_id = p_user_id
      AND ua.earned_at IS NOT NULL
    GROUP BY gt.platform_id, gt.platform_game_id, gt.name, COALESCE(gt.proxied_cover_url, gt.cover_url)
  ),
  best_game AS (
    SELECT * FROM game_completion
    ORDER BY earned_count DESC, total_count DESC
    LIMIT 1
  )
  SELECT 
    bg.platform_id,
    bg.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    a.name as achievement_name,
    COALESCE(a.proxied_icon_url, a.icon_url) as achievement_icon_url,
    bg.game_name,
    bg.game_cover_url
  FROM best_game bg
  JOIN user_achievements ua ON 
    bg.platform_id = ua.platform_id 
    AND bg.platform_game_id = ua.platform_game_id
  JOIN achievements a ON 
    ua.platform_id = a.platform_id 
    AND ua.platform_game_id = a.platform_game_id 
    AND ua.platform_achievement_id = a.platform_achievement_id
  WHERE ua.user_id = p_user_id
    AND ua.earned_at IS NOT NULL
  ORDER BY ua.earned_at DESC
  LIMIT 1;
END;
$$;

-- Update get_sweatiest_platinum_v2
CREATE OR REPLACE FUNCTION public.get_sweatiest_platinum_v2(p_user_id uuid)
RETURNS TABLE(
  platform_id bigint,
  platform_game_id text,
  platform_achievement_id text,
  earned_at timestamp with time zone,
  rarity_global numeric,
  achievement_name text,
  achievement_icon_url text,
  game_name text,
  game_cover_url text
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    a.name as achievement_name,
    COALESCE(a.proxied_icon_url, a.icon_url) as achievement_icon_url,
    gt.name as game_name,
    COALESCE(gt.proxied_cover_url, gt.cover_url) as game_cover_url
  FROM user_achievements ua
  JOIN achievements a ON 
    ua.platform_id = a.platform_id 
    AND ua.platform_game_id = a.platform_game_id 
    AND ua.platform_achievement_id = a.platform_achievement_id
  JOIN game_titles gt ON 
    ua.platform_id = gt.platform_id 
    AND ua.platform_game_id = gt.platform_game_id
  WHERE ua.user_id = p_user_id
    AND ua.earned_at IS NOT NULL
    AND a.rarity_global IS NOT NULL
    AND (a.tier = 'platinum' OR a.is_rare = true)
  ORDER BY a.rarity_global ASC
  LIMIT 1;
END;
$$;

-- Update get_recent_notable_achievements_v2
CREATE OR REPLACE FUNCTION public.get_recent_notable_achievements_v2(p_user_id uuid, p_limit integer DEFAULT 10)
RETURNS TABLE(
  platform_id bigint,
  platform_game_id text,
  platform_achievement_id text,
  earned_at timestamp with time zone,
  rarity_global numeric,
  achievement_name text,
  achievement_icon_url text,
  game_name text,
  game_cover_url text
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ua.platform_id,
    ua.platform_game_id,
    ua.platform_achievement_id,
    ua.earned_at,
    a.rarity_global,
    a.name as achievement_name,
    COALESCE(a.proxied_icon_url, a.icon_url) as achievement_icon_url,
    gt.name as game_name,
    COALESCE(gt.proxied_cover_url, gt.cover_url) as game_cover_url
  FROM user_achievements ua
  JOIN achievements a ON 
    ua.platform_id = a.platform_id 
    AND ua.platform_game_id = a.platform_game_id 
    AND ua.platform_achievement_id = a.platform_achievement_id
  JOIN game_titles gt ON 
    ua.platform_id = gt.platform_id 
    AND ua.platform_game_id = gt.platform_game_id
  WHERE ua.user_id = p_user_id
    AND ua.earned_at IS NOT NULL
    AND a.rarity_global IS NOT NULL
    AND a.rarity_global < 15.0
  ORDER BY ua.earned_at DESC
  LIMIT p_limit;
END;
$$;
