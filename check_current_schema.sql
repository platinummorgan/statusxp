-- Check what columns actually exist in game_titles RIGHT NOW
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'game_titles' 
ORDER BY ordinal_position;
