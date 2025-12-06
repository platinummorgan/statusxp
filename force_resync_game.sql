-- INSTRUCTIONS: 
-- 1. First run find_platinum_game.sql to find a game to test with (e.g., Cloudpunk)
-- 2. Copy the user_games.id for that game
-- 3. Replace 'YOUR_GAME_ID_HERE' below with that ID
-- 4. Run this to delete the game (it will be re-synced next sync)

-- Delete the game from user_games to force re-sync
-- DELETE FROM user_games WHERE id = YOUR_GAME_ID_HERE;

-- Example: DELETE FROM user_games WHERE id = 123;
