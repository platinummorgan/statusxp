-- Check if activity feed entries exist for your user
SELECT 
  af.id,
  af.story_text,
  af.event_type,
  af.change_type,
  af.old_value,
  af.new_value,
  af.change_amount,
  af.game_title,
  af.gold_count,
  af.silver_count,
  af.bronze_count,
  af.event_date,
  af.created_at,
  af.generation_failed,
  af.ai_model
FROM activity_feed af
WHERE af.user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com')
ORDER BY af.created_at DESC
LIMIT 20;

-- Check snapshots (to see if sync is creating them)
SELECT 
  id,
  total_statusxp,
  platinum_count,
  psn_gold_count,
  psn_silver_count,
  psn_bronze_count,
  latest_game_title,
  synced_at
FROM user_stat_snapshots
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com')
ORDER BY synced_at DESC
LIMIT 10;

-- Check recent PSN sync logs
SELECT 
  id,
  status,
  started_at,
  completed_at,
  games_processed,
  trophies_synced,
  error_message
FROM psn_sync_logs
WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com')
ORDER BY started_at DESC
LIMIT 5;
