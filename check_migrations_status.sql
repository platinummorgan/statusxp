-- Quick check: Do the premium and AI credit tables already exist?
-- Run this in Supabase SQL Editor to check

-- Check for premium/sync tables
SELECT 
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_premium_status') 
    THEN '✅ user_premium_status exists' 
    ELSE '❌ user_premium_status missing' 
  END as premium_status,
  
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_sync_history') 
    THEN '✅ user_sync_history exists' 
    ELSE '❌ user_sync_history missing' 
  END as sync_history,
  
  CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'can_user_sync') 
    THEN '✅ can_user_sync() function exists' 
    ELSE '❌ can_user_sync() function missing' 
  END as sync_function;

-- Check for AI credit tables
SELECT 
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_ai_credits') 
    THEN '✅ user_ai_credits exists' 
    ELSE '❌ user_ai_credits missing' 
  END as ai_credits,
  
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_ai_daily_usage') 
    THEN '✅ user_ai_daily_usage exists' 
    ELSE '❌ user_ai_daily_usage missing' 
  END as ai_usage,
  
  CASE WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_ai_pack_purchases') 
    THEN '✅ user_ai_pack_purchases exists' 
    ELSE '❌ user_ai_pack_purchases missing' 
  END as ai_purchases,
  
  CASE WHEN EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'can_use_ai') 
    THEN '✅ can_use_ai() function exists' 
    ELSE '❌ can_use_ai() function missing' 
  END as ai_function;

-- Check if monthly_ai_credits column exists in user_premium_status
SELECT 
  CASE WHEN EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'user_premium_status' 
    AND column_name = 'monthly_ai_credits'
  ) 
    THEN '✅ monthly_ai_credits column exists' 
    ELSE '❌ monthly_ai_credits column missing' 
  END as monthly_credits_column;
