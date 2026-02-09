# Delete all Twitch EventSub subscriptions
$clientId = "wugdu8pbxckurjet128o523dll87f7"
$clientSecret = "xgrzr7secgpc7v1y0hqq7vk58vjq1x"

# Get token
Write-Host "Getting access token..." -ForegroundColor Cyan
$tokenResponse = Invoke-RestMethod -Uri "https://id.twitch.tv/oauth2/token" -Method POST -Body @{
    client_id = $clientId
    client_secret = $clientSecret
    grant_type = "client_credentials"
}
$accessToken = $tokenResponse.access_token

# Get all subscriptions
$subsResponse = Invoke-RestMethod -Uri "https://api.twitch.tv/helix/eventsub/subscriptions" -Headers @{
    "Authorization" = "Bearer $accessToken"
    "Client-Id" = $clientId
}

# Delete each one
foreach ($sub in $subsResponse.data) {
    Write-Host "Deleting $($sub.type)..." -ForegroundColor Yellow
    Invoke-RestMethod -Uri "https://api.twitch.tv/helix/eventsub/subscriptions?id=$($sub.id)" `
        -Method DELETE `
        -Headers @{
            "Authorization" = "Bearer $accessToken"
            "Client-Id" = $clientId
        }
    Write-Host "  ✅ Deleted" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ All webhooks deleted" -ForegroundColor Green
