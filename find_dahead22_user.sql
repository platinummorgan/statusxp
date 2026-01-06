-- Find DaHead22 user with different search methods
-- Problem: Username 'dahead22' not found in profiles table

-- Search 1: Case-insensitive with wildcards
SELECT 
    id as user_id,
    username,
    display_name,
    psn_online_id,
    xbox_gamertag,
    created_at
FROM profiles
WHERE 
    LOWER(username) LIKE '%dahead%'
    OR LOWER(display_name) LIKE '%dahead%'
    OR LOWER(psn_online_id) LIKE '%dahead%'
    OR LOWER(xbox_gamertag) LIKE '%dahead%';

-- Search 2: Find users with platinum trophies (if they have trophy data, they must exist)
SELECT DISTINCT
    p.id as user_id,
    p.username,
    p.psn_online_id,
    COUNT(*) as platinum_count
FROM user_achievements ua
INNER JOIN achievements a ON ua.achievement_id = a.id
INNER JOIN profiles p ON ua.user_id = p.id
WHERE a.is_platinum = true
  AND (
    LOWER(p.username) LIKE '%dahead%'
    OR LOWER(p.psn_online_id) LIKE '%dahead%'
  )
GROUP BY p.id, p.username, p.psn_online_id;

-- Search 3: Check if there's a merged account
SELECT 
    id as user_id,
    username,
    psn_online_id,
    merged_into_user_id,
    merged_at
FROM profiles
WHERE merged_into_user_id IS NOT NULL
  AND (
    LOWER(username) LIKE '%dahead%'
    OR LOWER(psn_online_id) LIKE '%dahead%'
  );

-- Search 4: Find all users (limited to 50) to see naming patterns
SELECT 
    id as user_id,
    username,
    psn_online_id,
    created_at
FROM profiles
ORDER BY created_at DESC
LIMIT 50;

-- Search 5: Check auth.users for orphaned Apple identity
-- Note: Requires service_role access in Supabase Dashboard
-- SELECT 
--     u.id,
--     u.email,
--     i.provider,
--     i.identity_data->>'sub' as apple_id
-- FROM auth.users u
-- LEFT JOIN auth.identities i ON u.id = i.user_id
-- WHERE i.provider = 'apple'
--   AND u.id NOT IN (SELECT id FROM profiles);
