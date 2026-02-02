-- Verify: Can we see the new user in StatusXP leaderboard?
-- User: ZFR_RaFa (ff194d87-37d5-4219-a71d-a52bb81709e6)

-- This mimics the exact query the Flutter app runs
SELECT 
  lc.user_id,
  lc.total_statusxp,
  lc.total_game_entries,
  p.display_name,
  p.preferred_display_platform,
  p.psn_online_id,
  p.psn_avatar_url,
  p.xbox_gamertag,
  p.xbox_avatar_url,
  p.steam_display_name,
  p.steam_avatar_url,
  p.show_on_leaderboard
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE p.show_on_leaderboard = true
  AND lc.total_statusxp > 0
ORDER BY lc.total_statusxp DESC
LIMIT 100;

-- Count how many users are on the leaderboard
SELECT COUNT(*) as total_on_leaderboard
FROM leaderboard_cache lc
JOIN profiles p ON p.id = lc.user_id
WHERE p.show_on_leaderboard = true
  AND lc.total_statusxp > 0;

-- Check the user's rank
SELECT 
  rank,
  display_name,
  total_statusxp
FROM (
  SELECT 
    ROW_NUMBER() OVER (ORDER BY lc.total_statusxp DESC) as rank,
    p.display_name,
    lc.total_statusxp,
    lc.user_id
  FROM leaderboard_cache lc
  JOIN profiles p ON p.id = lc.user_id
  WHERE p.show_on_leaderboard = true
    AND lc.total_statusxp > 0
) ranked
WHERE user_id = 'ff194d87-37d5-4219-a71d-a52bb81709e6';

-- Check ALL recent users and their leaderboard status
SELECT 
  p.display_name,
  p.username,
  p.created_at,
  lc.total_statusxp,
  CASE 
    WHEN lc.user_id IS NULL THEN '❌ Not in cache'
    WHEN lc.total_statusxp = 0 THEN '⚠️ Zero StatusXP'
    WHEN p.show_on_leaderboard = false THEN '🔒 Hidden'
    ELSE '✅ Visible'
  END as leaderboard_status
FROM profiles p
LEFT JOIN leaderboard_cache lc ON lc.user_id = p.id
WHERE p.created_at >= NOW() - INTERVAL '7 days'
  AND p.merged_into_user_id IS NULL
ORDER BY p.created_at DESC;
