SELECT id, email, display_name, steam_display_name, psn_display_name 
FROM profiles 
ORDER BY created_at DESC 
LIMIT 5;