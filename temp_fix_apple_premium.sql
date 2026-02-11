-- Fix missing premium status for Apple user
-- User: Hey_Its_Me_Sammy (bt444k2582@privaterelay.appleid.com)
-- Issue: User exists but has no premium status record

-- Option 1: Create a new premium status record for Apple IAP
-- (Only run if user should have premium)
INSERT INTO user_premium_status (
  user_id,
  is_premium,
  premium_source,
  premium_expires_at,
  premium_since,
  created_at,
  updated_at
) VALUES (
  'a6deaf66-244f-4c8d-bef5-e3e1184370b7',
  true,
  'apple',
  '2027-02-09 00:00:00+00',  -- Set appropriate expiry date
  '2026-01-08 23:54:45+00',  -- When they signed up
  NOW(),
  NOW()
)
ON CONFLICT (user_id) DO UPDATE SET
  is_premium = true,
  premium_source = 'apple',
  premium_expires_at = EXCLUDED.premium_expires_at,
  updated_at = NOW();

-- Option 2: Just create empty record (not premium) so Apple can update it
-- INSERT INTO user_premium_status (user_id, is_premium, created_at, updated_at)
-- VALUES ('a6deaf66-244f-4c8d-bef5-e3e1184370b7', false, NOW(), NOW())
-- ON CONFLICT (user_id) DO NOTHING;

-- Verify the fix
SELECT 
  user_id,
  is_premium,
  premium_source,
  premium_expires_at,
  premium_since
FROM user_premium_status
WHERE user_id = 'a6deaf66-244f-4c8d-bef5-e3e1184370b7';
