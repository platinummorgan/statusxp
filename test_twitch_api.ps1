# Test Twitch API Access
# Verifies that the Twitch credentials work and checks if a specific user is subscribed

$clientId = "wugdu8pbxckurjet128o523dll87f7"
$clientSecret = "ze3da0tptbqcmj57p3wliq1r0kfcjf"
$broadcasterId = "39e33dec307f13908c60deffa5b9cecbb3f5c739b2a5"

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

# Get broadcaster info
Write-Host "Getting broadcaster info..." -ForegroundColor Cyan
$broadcasterResponse = Invoke-RestMethod -Uri "https://api.twitch.tv/helix/users?id=$broadcasterId" -Headers @{
    "Authorization" = "Bearer $accessToken"
    "Client-Id" = $clientId
}
Write-Host "Broadcaster: $($broadcasterResponse.data[0].display_name) (@$($broadcasterResponse.data[0].login))" -ForegroundColor Green
Write-Host ""

# Check subscriptions (requires broadcaster token or specific permissions)
Write-Host "Checking if a test user is subscribed..." -ForegroundColor Cyan
Write-Host "Enter the Twitch user ID to check (or press Enter to skip):" -ForegroundColor Yellow
$testUserId = Read-Host

if ($testUserId) {
    try {
        $subResponse = Invoke-RestMethod -Uri "https://api.twitch.tv/helix/subscriptions/user?broadcaster_id=$broadcasterId&user_id=$testUserId" -Headers @{
            "Authorization" = "Bearer $accessToken"
            "Client-Id" = $clientId
        }
        
        if ($subResponse.data -and $subResponse.data.Count -gt 0) {
            Write-Host "✅ User IS subscribed! Tier: $($subResponse.data[0].tier)" -ForegroundColor Green
        } else {
            Write-Host "❌ User is NOT subscribed" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error checking subscription: $_" -ForegroundColor Red
        Write-Host "Status: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
    }
} else {
    Write-Host "⏩ Skipped user check" -ForegroundColor Yellow
}
