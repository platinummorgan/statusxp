# Deploy and run the game covers backfill function
# This fixes CORS issues by uploading external images to Supabase Storage

Write-Host "🚀 Deploying backfill-game-covers function..." -ForegroundColor Cyan
supabase functions deploy backfill-game-covers

Write-Host "`n📦 Starting backfill for PSN games (platform_id: 1)..." -ForegroundColor Cyan
$response = Invoke-RestMethod -Method Post `
    -Uri "https://ksrigcmunjkemtfujedm.supabase.co/functions/v1/backfill-game-covers" `
    -Headers @{
        "Authorization" = "Bearer YOUR_ANON_KEY"
        "Content-Type" = "application/json"
    } `
    -Body (@{
        platform_ids = @(1)  # PSN
        batch_size = 50
        offset = 0
    } | ConvertTo-Json)

Write-Host "`n✅ Results:" -ForegroundColor Green
$response | ConvertTo-Json -Depth 5

Write-Host "`nTo process more games, increment offset by 50 and run again" -ForegroundColor Yellow
