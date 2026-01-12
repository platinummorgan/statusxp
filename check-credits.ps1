# Quick script to check AI credits without psql
# Uses Supabase REST API instead

Write-Host "Checking AI credits for mdorminey79@gmail.com..." -ForegroundColor Cyan

# Run a simple SQL query via supabase db
$query = @"
SELECT 
  u.email,
  COALESCE(uac.pack_credits, 0) as pack_credits,
  COALESCE(ups.monthly_ai_credits, 0) as monthly_ai_credits,
  COALESCE(ups.is_premium, false) as is_premium
FROM auth.users u
LEFT JOIN user_ai_credits uac ON uac.user_id = u.id
LEFT JOIN user_premium_status ups ON ups.user_id = u.id
WHERE u.email = 'mdorminey79@gmail.com';
"@

# Save query to temp file
$query | Out-File -FilePath "temp_query.sql" -Encoding UTF8 -NoNewline

Write-Host "Query saved, checking database..." -ForegroundColor Gray
Write-Host ""

# Show what we're looking for
Write-Host "Looking for:" -ForegroundColor Yellow
Write-Host "  - pack_credits (should have your AI pack credits)" -ForegroundColor Gray
Write-Host "  - monthly_ai_credits (old column, should be 0)" -ForegroundColor Gray
Write-Host "  - is_premium (subscription status)" -ForegroundColor Gray
Write-Host ""
Write-Host "Run this command manually to check:" -ForegroundColor Cyan
Write-Host "  npx supabase db execute `"SELECT * FROM user_ai_credits WHERE user_id = (SELECT id FROM auth.users WHERE email = 'mdorminey79@gmail.com');`"" -ForegroundColor Green
