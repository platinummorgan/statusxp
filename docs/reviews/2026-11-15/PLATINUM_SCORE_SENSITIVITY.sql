-- Read-only simulation of native versus estimated Platinum rarity at unit weight.
-- Uses the existing curve, numeric(6,2) storage, multipliers, and per-game rounding.
BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY;
SET LOCAL statement_timeout = '120s';
SET LOCAL work_mem = '64MB';

WITH
excluded_ids(game_id) AS (
  SELECT unnest(ARRAY[
    'NPWR00156_00','NPWR00160_00','NPWR00214_00','NPWR00234_00',
    'NPWR00302_00','NPWR00352_00','NPWR00374_00','NPWR00404_00',
    'NPWR00494_00','NPWR00499_00','NPWR00561_00','NPWR00599_00',
    'NPWR00603_00','NPWR00612_00','NPWR00698_00','NPWR00722_00',
    'NPWR00736_00','NPWR00745_00','NPWR00845_00','NPWR22270_00',
    'NPWR25713_00','NPWR30568_00','NPWR31226_00','NPWR34057_00',
    'NPWR34058_00','NPWR34065_00','NPWR34066_00','NPWR34424_00',
    'NPWR34741_00','NPWR35186_00','NPWR35219_00','NPWR29403_00',
    'NPWR29929_00','NPWR31273_00','NPWR31607_00','NPWR32435_00',
    'NPWR32558_00','NPWR32718_00','NPWR32800_00','NPWR33080_00',
    'NPWR34061_00','NPWR34555_00','NPWR35127_00'
  ]::text[])
),
catalog AS MATERIALIZED (
  SELECT a.platform_id, a.platform_game_id, a.platform_achievement_id,
    a.rarity_global,
    coalesce(a.is_platinum, false)
      OR coalesce(a.metadata->>'psn_trophy_type' = 'platinum', false) AS platinum,
    nullif(a.metadata->>'trophy_group_id', '') AS trophy_group,
    coalesce(a.metadata->>'is_dlc' = 'true', false) AS dlc
  FROM public.achievements a
  WHERE a.platform_id IN (1, 2, 5, 9)
),
list_inputs AS (
  SELECT platform_id, platform_game_id,
    count(*) FILTER (WHERE platinum) AS platinum_count,
    max(platform_achievement_id) FILTER (WHERE platinum) AS platinum_id,
    max(trophy_group) FILTER (WHERE platinum) AS platinum_group,
    max(rarity_global) FILTER (WHERE platinum) AS native_rarity,
    min(rarity_global) FILTER (
      WHERE NOT platinum AND trophy_group = 'default'
    ) AS proxy_rarity,
    count(*) FILTER (WHERE trophy_group IS NULL) AS unknown_groups,
    count(*) FILTER (
      WHERE NOT platinum AND trophy_group = 'default'
    ) AS base_trophy_count,
    count(*) FILTER (
      WHERE trophy_group = 'default'
        AND (rarity_global IS NULL OR rarity_global < 0 OR rarity_global > 100)
    ) AS invalid_rarities,
    count(*) FILTER (WHERE trophy_group = 'default' AND dlc) AS conflicting_dlc,
    string_agg(platform_achievement_id, ',' ORDER BY platform_achievement_id)
      FILTER (WHERE NOT platinum AND trophy_group = 'default') AS membership
  FROM catalog
  GROUP BY platform_id, platform_game_id
),
eligible AS MATERIALIZED (
  SELECT li.*
  FROM list_inputs li
  WHERE platinum_count = 1 AND platinum_group = 'default'
    AND unknown_groups = 0 AND base_trophy_count > 0
    AND invalid_rarities = 0 AND conflicting_dlc = 0
    AND native_rarity IS NOT NULL
),
consistent_ids AS (
  SELECT platform_game_id
  FROM eligible
  GROUP BY platform_game_id
  HAVING count(DISTINCT (native_rarity, proxy_rarity, membership)) = 1
),
point_values AS MATERIALIZED (
  SELECT e.*,
    round(0.5 + 11.5 * power(1 - native_rarity / 100, 3), 2) AS native_points,
    round(0.5 + 11.5 * power(1 - proxy_rarity / 100, 3), 2) AS proxy_points
  FROM eligible e
  JOIN consistent_ids USING (platform_game_id)
  WHERE e.proxy_rarity >= e.native_rarity
    AND NOT EXISTS (
      SELECT 1 FROM excluded_ids x WHERE x.game_id = e.platform_game_id
    )
),
unique_lists AS MATERIALIZED (
  SELECT DISTINCT ON (platform_game_id) *
  FROM point_values
  ORDER BY platform_game_id, platform_id
),
cohort_rows AS (
  SELECT 'all'::text AS cohort, u.* FROM unique_lists u
  UNION ALL
  SELECT 'below_1_percent', u.* FROM unique_lists u WHERE native_rarity < 1
  UNION ALL
  SELECT 'below_1_percent_positive', u.*
  FROM unique_lists u WHERE native_rarity > 0 AND native_rarity < 1
),
point_stats AS (
  SELECT cohort, count(*) AS lists,
    count(*) FILTER (WHERE native_points = proxy_points) AS identical_points,
    avg(native_points) AS mean_native_points,
    avg(proxy_points) AS mean_proxy_points,
    avg(native_points - proxy_points) AS mean_point_loss,
    percentile_cont(0.5) WITHIN GROUP (
      ORDER BY native_points - proxy_points
    ) AS median_point_loss,
    percentile_cont(0.9) WITHIN GROUP (
      ORDER BY native_points - proxy_points
    ) AS p90_point_loss,
    percentile_cont(0.95) WITHIN GROUP (
      ORDER BY native_points - proxy_points
    ) AS p95_point_loss,
    max(native_points - proxy_points) AS max_point_loss,
    avg(100 * (native_points - proxy_points) / native_points) AS mean_relative_loss_percent,
    max(100 * (native_points - proxy_points) / native_points) AS max_relative_loss_percent
  FROM cohort_rows
  GROUP BY cohort
),
board AS MATERIALIZED (
  SELECT lc.user_id, lc.total_statusxp, lc.last_updated
  FROM public.leaderboard_cache lc
  JOIN public.profiles p ON p.id = lc.user_id
  WHERE p.show_on_leaderboard = true AND lc.total_statusxp > 0
),
earned_platinums AS MATERIALIZED (
  SELECT ul.user_id, v.*,
    coalesce(a.rarity_multiplier, 1.0) AS rarity_multiplier,
    CASE WHEN a.include_in_score
      THEN a.base_status_xp * coalesce(a.rarity_multiplier, 1.0)
      ELSE 0 END AS existing_platinum_points
  -- Undated unlocks are constrained to Xbox, so dated rows cover this PSN audit.
  FROM public.user_achievements ul
  JOIN point_values v ON v.platform_id = ul.platform_id
    AND v.platform_game_id = ul.platform_game_id
    AND v.platinum_id = ul.platform_achievement_id
  JOIN public.achievements a ON a.platform_id = ul.platform_id
    AND a.platform_game_id = ul.platform_game_id
    AND a.platform_achievement_id = ul.platform_achievement_id
  JOIN board b ON b.user_id = ul.user_id
),
earned_games AS MATERIALIZED (
  SELECT DISTINCT user_id, platform_id, platform_game_id
  FROM earned_platinums
),
game_inputs AS MATERIALIZED (
  SELECT eg.user_id, eg.platform_id, eg.platform_game_id,
    sum(CASE WHEN a.include_in_score
      THEN a.base_status_xp * coalesce(a.rarity_multiplier, 1.0)
      ELSE 0 END) AS current_raw
  FROM earned_games eg
  JOIN public.user_achievements ul USING (
    user_id, platform_id, platform_game_id
  )
  JOIN public.achievements a USING (
    platform_id, platform_game_id, platform_achievement_id
  )
  JOIN public.games g USING (platform_id, platform_game_id)
  GROUP BY eg.user_id, eg.platform_id, eg.platform_game_id
),
game_deltas AS MATERIALIZED (
  SELECT e.user_id, e.platform_id, e.platform_game_id, e.native_rarity,
    e.native_points, e.proxy_points, e.rarity_multiplier,
    gi.current_raw::integer AS current_game_points,
    (gi.current_raw - e.existing_platinum_points
      + e.native_points * e.rarity_multiplier)::integer
      - gi.current_raw::integer AS native_gain,
    (gi.current_raw - e.existing_platinum_points
      + e.proxy_points * e.rarity_multiplier)::integer
      - gi.current_raw::integer AS proxy_gain
  FROM earned_platinums e
  JOIN game_inputs gi USING (user_id, platform_id, platform_game_id)
),
user_deltas AS (
  SELECT user_id, count(*) AS qualifying_platinums,
    sum(native_gain) AS native_gain, sum(proxy_gain) AS proxy_gain,
    sum(native_gain - proxy_gain) FILTER (
      WHERE native_rarity < 1
    ) AS below_1_point_loss
  FROM game_deltas
  GROUP BY user_id
),
projected AS (
  SELECT b.*,
    coalesce(d.qualifying_platinums, 0) AS qualifying_platinums,
    coalesce(d.native_gain, 0) AS native_gain,
    coalesce(d.proxy_gain, 0) AS proxy_gain,
    coalesce(d.below_1_point_loss, 0) AS below_1_point_loss,
    b.total_statusxp + coalesce(d.native_gain, 0) AS native_total,
    b.total_statusxp + coalesce(d.proxy_gain, 0) AS proxy_total
  FROM board b LEFT JOIN user_deltas d USING (user_id)
),
ranked AS MATERIALIZED (
  SELECT p.*,
    row_number() OVER (ORDER BY total_statusxp DESC, user_id) AS current_position,
    row_number() OVER (ORDER BY native_total DESC, user_id) AS native_position,
    row_number() OVER (ORDER BY proxy_total DESC, user_id) AS proxy_position,
    rank() OVER (ORDER BY native_total DESC) AS native_rank_low,
    rank() OVER (ORDER BY native_total DESC)
      + count(*) OVER (PARTITION BY native_total) - 1 AS native_rank_high,
    rank() OVER (ORDER BY proxy_total DESC) AS proxy_rank_low,
    rank() OVER (ORDER BY proxy_total DESC)
      + count(*) OVER (PARTITION BY proxy_total) - 1 AS proxy_rank_high
  FROM projected p
),
canonical_users AS MATERIALIZED (
  SELECT b.user_id FROM board b
  WHERE EXISTS (SELECT 1 FROM earned_games e WHERE e.user_id = b.user_id)
  ORDER BY b.total_statusxp DESC LIMIT 3
),
canonical_results AS MATERIALIZED (
  SELECT u.user_id, c.platform_id, c.platform_game_id, c.statusxp_effective
  FROM canonical_users u
  CROSS JOIN LATERAL public.calculate_statusxp_with_stacks(u.user_id) c
),
canonical_checks AS (
  SELECT gi.current_raw::integer AS simulated, c.statusxp_effective AS canonical
  FROM canonical_results c
  JOIN game_inputs gi ON gi.user_id = c.user_id
    AND gi.platform_id = c.platform_id
    AND gi.platform_game_id = c.platform_game_id
),
pair_changes AS (
  SELECT
    count(*) FILTER (WHERE
      (a.native_total > b.native_total AND a.proxy_total < b.proxy_total)
      OR (a.native_total < b.native_total AND a.proxy_total > b.proxy_total)
    ) AS strict_order_reversals,
    count(*) FILTER (WHERE a.native_total <> b.native_total
      AND a.proxy_total = b.proxy_total) AS ties_created,
    count(*) FILTER (WHERE a.native_total = b.native_total
      AND a.proxy_total <> b.proxy_total) AS ties_broken
  FROM ranked a JOIN ranked b ON a.user_id < b.user_id
)
SELECT jsonb_build_object(
  'read_only', current_setting('transaction_read_only'),
  'snapshot_time', transaction_timestamp(),
  'excluded_inconsistent_ids', (SELECT count(*) FROM excluded_ids),
  'point_statistics', (SELECT jsonb_agg(to_jsonb(s) ORDER BY cohort) FROM point_stats s),
  'curve_example', jsonb_build_object(
    'native_rarity', 0.1, 'proxy_rarity', 0.2,
    'native_points', round(0.5 + 11.5 * power(1 - 0.1 / 100, 3), 2),
    'proxy_points', round(0.5 + 11.5 * power(1 - 0.2 / 100, 3), 2)
  ),
  'catalog_checks', (
    SELECT jsonb_build_object(
      'qualifying_entries', count(*),
      'nonunit_multipliers', count(*) FILTER (WHERE coalesce(a.rarity_multiplier, 1) <> 1),
      'currently_included', count(*) FILTER (WHERE a.include_in_score),
      'currently_nonzero_base', count(*) FILTER (WHERE a.base_status_xp <> 0)
    )
    FROM point_values v JOIN public.achievements a ON a.platform_id = v.platform_id
      AND a.platform_game_id = v.platform_game_id AND a.platform_achievement_id = v.platinum_id
  ),
  'canonical_checks', (
    SELECT jsonb_build_object('checked_games', count(*),
      'mismatches', count(*) FILTER (WHERE simulated <> canonical))
    FROM canonical_checks
  ),
  'leaderboard_statistics', (
    SELECT jsonb_build_object(
      'players', count(*),
      'players_with_qualifying_platinums', count(*) FILTER (WHERE qualifying_platinums > 0),
      'qualifying_earned_platinums', sum(qualifying_platinums),
      'players_with_point_loss', count(*) FILTER (WHERE native_total <> proxy_total),
      'median_point_loss', percentile_cont(0.5) WITHIN GROUP (ORDER BY native_total - proxy_total),
      'max_point_loss', max(native_total - proxy_total),
      'total_point_loss', sum(native_total - proxy_total),
      'below_1_total_point_loss', sum(below_1_point_loss),
      'positions_changed', count(*) FILTER (WHERE native_position <> proxy_position),
      'max_position_change', max(abs(native_position - proxy_position)),
      'definite_position_changes', count(*) FILTER (
        WHERE native_rank_high < proxy_rank_low OR proxy_rank_high < native_rank_low),
      'native_enabling_positions_changed', count(*) FILTER (WHERE current_position <> native_position),
      'proxy_enabling_positions_changed', count(*) FILTER (WHERE current_position <> proxy_position),
      'top_10_membership_changes', count(*) FILTER (
        WHERE (native_position <= 10) <> (proxy_position <= 10)),
      'cache_oldest', min(last_updated), 'cache_newest', max(last_updated)
    ) FROM ranked
  ),
  'pair_changes', (SELECT to_jsonb(p) FROM pair_changes p),
  'game_rounding_statistics', (
    SELECT jsonb_build_object(
      'games', count(*),
      'games_with_point_loss', count(*) FILTER (WHERE native_gain <> proxy_gain),
      'max_game_point_loss', max(native_gain - proxy_gain),
      'below_1_games', count(*) FILTER (WHERE native_rarity < 1),
      'below_1_games_with_point_loss', count(*) FILTER (
        WHERE native_rarity < 1 AND native_gain <> proxy_gain),
      'below_1_max_game_point_loss', max(native_gain - proxy_gain) FILTER (WHERE native_rarity < 1)
    ) FROM game_deltas
  ),
  'leaderboard_rows', (
    SELECT jsonb_agg(jsonb_build_object(
      'player', 'Player ' || lpad(current_position::text, 3, '0'),
      'current_score', total_statusxp,
      'qualifying_platinums', qualifying_platinums,
      'native_score', native_total, 'proxy_score', proxy_total,
      'point_loss', native_total - proxy_total,
      'below_1_point_loss', below_1_point_loss,
      'current_position', current_position,
      'native_position', native_position, 'proxy_position', proxy_position,
      'native_rank_low', native_rank_low, 'native_rank_high', native_rank_high,
      'proxy_rank_low', proxy_rank_low, 'proxy_rank_high', proxy_rank_high
    ) ORDER BY current_position) FROM ranked
  ),
  'largest_point_gaps', (
    SELECT jsonb_agg(to_jsonb(e)) FROM (
      SELECT u.platform_id, u.platform_game_id, g.name,
        u.native_rarity, u.proxy_rarity, u.native_points, u.proxy_points,
        u.native_points - u.proxy_points AS point_loss
      FROM unique_lists u JOIN public.games g USING (platform_id, platform_game_id)
      ORDER BY u.native_points - u.proxy_points DESC, u.platform_game_id LIMIT 10
    ) e
  ),
  'largest_below_1_gaps', (
    SELECT jsonb_agg(to_jsonb(e)) FROM (
      SELECT u.platform_id, u.platform_game_id, g.name,
        u.native_rarity, u.proxy_rarity, u.native_points, u.proxy_points,
        u.native_points - u.proxy_points AS point_loss
      FROM unique_lists u JOIN public.games g USING (platform_id, platform_game_id)
      WHERE u.native_rarity < 1
      ORDER BY u.native_points - u.proxy_points DESC, u.platform_game_id LIMIT 10
    ) e
  )
) AS sensitivity;

ROLLBACK;
