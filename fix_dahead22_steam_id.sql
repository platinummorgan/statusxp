-- Fix DaHead22's corrupted Steam ID
-- Current: 75661198125708243 (missing leading 5)
-- Correct: 76561198125708243

UPDATE profiles 
SET steam_id = '76561198125708243'
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9'
  AND steam_id = '75661198125708243';

-- Verify the fix
SELECT id, steam_id, steam_display_name 
FROM profiles 
WHERE id = '3c5206fb-6806-4f95-80d6-29ee7e974be9';
