# Get Twitch app access token and register EventSub webhook for subscription.message

$clientId = $env:TWITCH_CLIENT_ID
if ([string]::IsNullOrWhiteSpace($clientId)) { throw "Set TWITCH_CLIENT_ID in the environment before running this script." }
$clientSecret = $env:TWITCH_CLIENT_SECRET
if ([string]::IsNullOrWhiteSpace($clientSecret)) { throw "Set TWITCH_CLIENT_SECRET in the environment before running this script." }
$broadcasterId = "47221283"
$webhookUrl = "https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-eventsub-webhook"
$webhookSecret = $env:TWITCH_EVENTSUB_SECRET
if ([string]::IsNullOrWhiteSpace($webhookSecret)) { throw "Set TWITCH_EVENTSUB_SECRET in the environment before running this script." }

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
