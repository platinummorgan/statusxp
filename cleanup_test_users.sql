-- Hide demo account from leaderboards

-- Hide the demo account
UPDATE profiles
SET show_on_leaderboard = FALSE
WHERE id IN (
  SELECT id FROM auth.users WHERE email = 'demo@statusxp.test'
);

-- Verify the change
SELECT 
  p.id,
  u.email,
  p.username,
  p.show_on_leaderboard
FROM profiles p
JOIN auth.users u ON u.id = p.id
WHERE u.email = 'demo@statusxp.test';
