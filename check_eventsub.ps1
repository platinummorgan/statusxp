# Check Twitch EventSub Subscriptions
$clientId = "wugdu8pbxckurjet128o523dll87f7"
$clientSecret = "xgrzr7secgpc7v1y0hqq7vk58vjq1x"

# Get app access token
Write-Host "Getting Twitch app access token..." -ForegroundColor Cyan
$tokenResponse = Invoke-RestMethod -Uri "https://id.twitch.tv/oauth2/token" -Method POST -Body @{
    client_id = $clientId
    client_secret = $clientSecret
    grant_type = "client_credentials"
}
$accessToken = $tokenResponse.access_token
Write-Host "✅ Got access token" -ForegroundColor Green
Write-Host ""

# Check EventSub subscriptions
Write-Host "Checking EventSub subscriptions..." -ForegroundColor Cyan
$subsResponse = Invoke-RestMethod -Uri "https://api.twitch.tv/helix/eventsub/subscriptions" -Headers @{
    "Authorization" = "Bearer $accessToken"
    "Client-Id" = $clientId
}

if ($subsResponse.data.Count -eq 0) {
    Write-Host "❌ NO EVENTSUB SUBSCRIPTIONS REGISTERED!" -ForegroundColor Red
    Write-Host "" 
    Write-Host "This is why premium won't auto-renew for your subscribers." -ForegroundColor Yellow
    Write-Host "You need to register webhooks for:" -ForegroundColor Yellow
    Write-Host "  - channel.subscribe" -ForegroundColor Cyan
    Write-Host "  - channel.subscription.message" -ForegroundColor Cyan
    Write-Host "  - channel.subscription.end" -ForegroundColor Cyan
} else {
    Write-Host "✅ Found $($subsResponse.data.Count) EventSub subscriptions" -ForegroundColor Green
    Write-Host ""
    foreach ($sub in $subsResponse.data) {
        Write-Host "Type: $($sub.type)" -ForegroundColor Cyan
        Write-Host "  Status: $($sub.status)" -ForegroundColor $(if ($sub.status -eq 'enabled') { 'Green' } else { 'Red' })
        Write-Host "  Callback: $($sub.transport.callback)" -ForegroundColor Gray
        Write-Host ""
    }
}
