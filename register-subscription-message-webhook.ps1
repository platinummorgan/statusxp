# Get Twitch app access token and register EventSub webhook for subscription.message

$clientId = "wugdu8pbxckurjet128o523dll87f7"
$clientSecret = "jhwx95zr72230d6dcicvclccet80ap"
$broadcasterId = "47221283"
$webhookUrl = "https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-eventsub-webhook"
$webhookSecret = "a2149f8760e5c3bd"

Write-Host "Getting app access token..." -ForegroundColor Cyan
$tokenResponse = Invoke-RestMethod -Uri "https://id.twitch.tv/oauth2/token" `
    -Method Post `
    -Body @{
        client_id = $clientId
        client_secret = $clientSecret
        grant_type = 'client_credentials'
    }

$appAccessToken = $tokenResponse.access_token
Write-Host "✅ Got app access token: $($appAccessToken.Substring(0,10))..." -ForegroundColor Green

Write-Host "`nRegistering EventSub webhook for channel.subscription.message..." -ForegroundColor Cyan
$body = @{
    type = 'channel.subscription.message'
    version = '1'
    condition = @{
        broadcaster_user_id = $broadcasterId
    }
    transport = @{
        method = 'webhook'
        callback = $webhookUrl
        secret = $webhookSecret
    }
} | ConvertTo-Json -Depth 10

try {
    $response = Invoke-RestMethod -Uri 'https://api.twitch.tv/helix/eventsub/subscriptions' `
        -Method Post `
        -Headers @{
            'Authorization' = "Bearer $appAccessToken"
            'Client-Id' = $clientId
            'Content-Type' = 'application/json'
        } `
        -Body $body

    Write-Host "✅ EventSub webhook registered successfully!" -ForegroundColor Green
    Write-Host "`nWebhook Details:" -ForegroundColor Yellow
    $response.data | ConvertTo-Json -Depth 10 | Write-Host
} catch {
    Write-Host "❌ Failed to register webhook:" -ForegroundColor Red
    Write-Host $_.Exception.Message
    if ($_.ErrorDetails) {
        Write-Host $_.ErrorDetails.Message
    }
}
