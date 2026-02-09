-- Update database to use Supabase Storage URLs instead of external PSN URLs
-- This fixes CORS issues on web by pointing to your own storage bucket

-- First, let's see the pattern for your Supabase project
-- Replace YOUR_PROJECT_ID with your actual project ID: ksrigcmunjkemtfujedm

UPDATE games
SET cover_url = 'https://ksrigcmunjkemtfujedm.supabase.co/storage/v1/object/public/game-covers/' 
    || platform_id || '/' || platform_game_id || '.png'
WHERE cover_url LIKE '%psnobj%' 
  OR cover_url LIKE '%image.api.playstation%'
  OR cover_url LIKE '%xbox%'
  OR cover_url LIKE '%steam%';

-- Check how many were updated
SELECT 
  COUNT(*) as total_games,
  COUNT(CASE WHEN cover_url LIKE '%supabase%' THEN 1 END) as using_supabase_storage,
  COUNT(CASE WHEN cover_url LIKE '%psnobj%' OR cover_url LIKE '%xbox%' OR cover_url LIKE '%steam%' THEN 1 END) as still_external
FROM games
WHERE cover_url IS NOT NULL;
