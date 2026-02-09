# Run Twitch Subscriber Backfill
# This checks ALL users with linked Twitch accounts and grants premium if they're subscribed

$serviceRoleKey = $env:SUPABASE_SERVICE_ROLE_KEY

if (-not $serviceRoleKey) {
    Write-Host "Error: SUPABASE_SERVICE_ROLE_KEY environment variable not set" -ForegroundColor Red
    Write-Host ""
    Write-Host "Run this first:" -ForegroundColor Yellow
    Write-Host '  $env:SUPABASE_SERVICE_ROLE_KEY = "your_service_role_key_here"' -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Get the key from: https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/settings/api" -ForegroundColor Yellow
    exit 1
}

Write-Host "Running Twitch subscriber backfill..." -ForegroundColor Cyan
Write-Host ""

$response = Invoke-RestMethod `
    -Uri "https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-backfill-subscribers" `
    -Method POST `
    -Headers @{
        "Authorization" = "Bearer $serviceRoleKey"
        "Content-Type" = "application/json"
    }

Write-Host "Results:" -ForegroundColor Green
$response | ConvertTo-Json -Depth 10 | Write-Host

Write-Host ""
Write-Host "✅ Backfill complete!" -ForegroundColor Green
