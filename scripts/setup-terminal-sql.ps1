# One-time setup for terminal SQL execution
Write-Host "=== Supabase Terminal SQL Setup ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Opening Supabase API settings page..." -ForegroundColor Yellow
Start-Process "https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/settings/api"
Write-Host ""
Write-Host "Please:" -ForegroundColor White
Write-Host "  1. Find the 'service_role' key (NOT the anon key)" -ForegroundColor White
Write-Host "  2. Click the 'Copy' button next to it" -ForegroundColor White
Write-Host "  3. Come back here" -ForegroundColor White
Write-Host ""
Read-Host "Press Enter when you have copied the service_role key"

Write-Host ""
$key = Read-Host "Paste the service_role key here" -AsSecureString
$plainKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($key))

# Set for current session
$env:SUPABASE_SERVICE_KEY = $plainKey

# Set permanently for user
[System.Environment]::SetEnvironmentVariable('SUPABASE_SERVICE_KEY', $plainKey, 'User')

Write-Host ""
Write-Host "✅ Service key configured!" -ForegroundColor Green
Write-Host ""
Write-Host "You can now run SQL queries directly in terminal:" -ForegroundColor Cyan
Write-Host "  .\run-query.ps1 .\check_my_qualifications.sql" -ForegroundColor White
Write-Host ""
Write-Host "Testing the setup..." -ForegroundColor Yellow

# Test it
.\run-query.ps1 .\check_my_qualifications.sql
