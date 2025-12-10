-- Create Demo Tester Account with Sample Data
-- Run this in Supabase SQL Editor to create test account for closed testing

-- Step 1: Create the demo user account
-- NOTE: You'll need to create this user via Supabase Auth UI first:
-- Email: demo@statusxp.test
-- Password: StatusXP2025!
-- Then come back and get the user_id from this query:

-- Get the demo user ID (run this after creating the user in Supabase Auth)
SELECT id as demo_user_id FROM auth.users WHERE email = 'demo@statusxp.test';

-- Step 2: Copy your user ID here (replace with your actual user ID)
-- Find your user ID by running: SELECT id FROM auth.users WHERE email = 'your-email@example.com';
DO $$
DECLARE
  v_source_user_id UUID := '84b60ad6-cb2c-484f-8953-bf814551fd7a'; -- REPLACE WITH YOUR USER ID
  v_demo_user_id UUID := (SELECT id FROM auth.users WHERE email = 'demo@statusxp.test');
  v_game_count INTEGER := 0;
BEGIN
  -- Check if demo user exists
  IF v_demo_user_id IS NULL THEN
    RAISE EXCEPTION 'Demo user not found. Create user "demo@statusxp.test" in Supabase Auth first.';
  END IF;

  RAISE NOTICE 'Demo user ID: %', v_demo_user_id;
  RAISE NOTICE 'Source user ID: %', v_source_user_id;

  -- Step 3: Create profile for demo user
  INSERT INTO profiles (id, username, psn_online_id, psn_avatar_url, psn_is_plus)
  SELECT 
    v_demo_user_id,
    'DemoTester',
    'StatusXP_Demo',
    psn_avatar_url,
    true -- Give demo user PS Plus badge
  FROM profiles
  WHERE id = v_source_user_id
  ON CONFLICT (id) DO UPDATE SET
    username = EXCLUDED.username,
    psn_online_id = EXCLUDED.psn_online_id,
    psn_avatar_url = EXCLUDED.psn_avatar_url,
    psn_is_plus = EXCLUDED.psn_is_plus;

  RAISE NOTICE '✅ Created profile for demo user';

  -- Step 4: Copy 10 games with best completion rates
  INSERT INTO user_games (
    user_id, game_title_id, platform_id, completion_percent, 
    total_trophies, earned_trophies, has_platinum, last_played_at, 
    bronze_trophies, silver_trophies, gold_trophies, platinum_trophies,
    statusxp_raw, statusxp_effective, stack_index, stack_multiplier, 
    base_completed, last_trophy_earned_at, rarest_earned_achievement_rarity,
    xbox_total_achievements, xbox_achievements_earned, xbox_current_gamerscore, xbox_max_gamerscore
  )
  SELECT 
    v_demo_user_id,
    game_title_id,
    platform_id,
    completion_percent,
    total_trophies,
    earned_trophies,
    has_platinum,
    last_played_at,
    bronze_trophies,
    silver_trophies,
    gold_trophies,
    platinum_trophies,
    statusxp_raw,
    statusxp_effective,
    stack_index,
    stack_multiplier,
    base_completed,
    last_trophy_earned_at,
    rarest_earned_achievement_rarity,
    xbox_total_achievements,
    xbox_achievements_earned,
    xbox_current_gamerscore,
    xbox_max_gamerscore
  FROM user_games
  WHERE user_id = v_source_user_id
  ORDER BY completion_percent DESC, has_platinum DESC
  LIMIT 10;

  GET DIAGNOSTICS v_game_count = ROW_COUNT;
  RAISE NOTICE '✅ Copied % games to demo user', v_game_count;

  -- Step 5: Copy achievements for those games
  -- Find achievement IDs that match the demo user's games
  INSERT INTO user_achievements (
    user_id, achievement_id, earned_at
  )
  SELECT DISTINCT
    v_demo_user_id,
    ua.achievement_id,
    ua.earned_at
  FROM user_achievements ua
  INNER JOIN achievements a ON a.id = ua.achievement_id
  WHERE ua.user_id = v_source_user_id
    AND a.game_title_id IN (
      SELECT game_title_id FROM user_games 
      WHERE user_id = v_demo_user_id
    )
  ON CONFLICT (user_id, achievement_id) DO NOTHING;

  RAISE NOTICE '✅ Copied achievements for demo games';

  -- Step 6: Give demo user some AI credits for testing
  INSERT INTO user_ai_credits (user_id, pack_credits)
  VALUES (v_demo_user_id, 10)
  ON CONFLICT (user_id) DO UPDATE SET
    pack_credits = 10,
    updated_at = NOW();

  RAISE NOTICE '✅ Added 10 AI pack credits for testing';

  -- Step 7: Set demo user as premium (optional - for testing premium features)
  INSERT INTO user_premium_status (user_id, is_premium, premium_since)
  VALUES (v_demo_user_id, false, NOW()) -- Set to true to test premium features
  ON CONFLICT (user_id) DO UPDATE SET
    is_premium = false, -- Change to true for premium testing
    premium_since = NOW();

  RAISE NOTICE '✅ Set premium status (currently: FREE - change to TRUE for premium testing)';

  -- Step 8: Create flex room data for demo user
  INSERT INTO flex_room_data (
    user_id, tagline, flex_of_all_time_id, rarest_flex_id, 
    most_time_sunk_id, sweatiest_platinum_id, superlatives
  )
  SELECT 
    v_demo_user_id,
    tagline,
    flex_of_all_time_id,
    rarest_flex_id,
    most_time_sunk_id,
    sweatiest_platinum_id,
    superlatives
  FROM flex_room_data
  WHERE user_id = v_source_user_id
  ON CONFLICT (user_id) DO UPDATE SET
    tagline = EXCLUDED.tagline,
    flex_of_all_time_id = EXCLUDED.flex_of_all_time_id,
    rarest_flex_id = EXCLUDED.rarest_flex_id,
    most_time_sunk_id = EXCLUDED.most_time_sunk_id,
    sweatiest_platinum_id = EXCLUDED.sweatiest_platinum_id,
    superlatives = EXCLUDED.superlatives;

  RAISE NOTICE '✅ Copied flex room data';

  RAISE NOTICE '';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Demo Account Ready! 🎉';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Email: demo@statusxp.test';
  RAISE NOTICE 'Password: StatusXP2025!';
  RAISE NOTICE 'Games copied: %', v_game_count;
  RAISE NOTICE 'AI Credits: 10 (for testing)';
  RAISE NOTICE 'Premium: FREE (change to TRUE in Step 7 to test premium)';
  RAISE NOTICE '========================================';

END $$;

-- Step 9: Verify the demo account data
SELECT 
  'Demo User Stats' as info,
  COUNT(DISTINCT ug.game_title_id) as total_games,
  COUNT(DISTINCT ua.achievement_id) as total_achievements,
  (SELECT pack_credits FROM user_ai_credits WHERE user_id = (SELECT id FROM auth.users WHERE email = 'demo@statusxp.test')) as ai_pack_credits
FROM user_games ug
LEFT JOIN user_achievements ua ON ua.user_id = ug.user_id
WHERE ug.user_id = (SELECT id FROM auth.users WHERE email = 'demo@statusxp.test');
