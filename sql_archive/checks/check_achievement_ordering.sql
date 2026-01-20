-- Check what ordering/sorting fields exist in achievements table
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'achievements'
    AND table_schema = 'public'
ORDER BY ordinal_position;

-- Sample some achievements to see if there's a sort pattern
SELECT 
    id,
    name,
    platform,
    psn_trophy_type,
    is_platinum,
    game_title_id
FROM achievements
WHERE game_title_id = 38 -- Deathloop as example
ORDER BY id
LIMIT 20;
