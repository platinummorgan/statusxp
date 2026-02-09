# Register Twitch EventSub Webhooks
# This tells Twitch to notify StatusXP when users subscribe/unsubscribe

$clientId = "wugdu8pbxckurjet128o523dll87f7"
$clientSecret = "xgrzr7secgpc7v1y0hqq7vk58vjq1x"
$broadcasterId = "47221283"  # Your Twitch user ID
$eventsubSecret = "26f9ce51db40b258c63ebc5f3b2c3aad06f0c789b6b4"  # From Supabase secrets

Write-Host "Getting Twitch access token..." -ForegroundColor Cyan
$tokenResponse = Invoke-RestMethod -Uri "https://id.twitch.tv/oauth2/token" -Method POST -Body @{
    client_id = $clientId
    client_secret = $clientSecret
    grant_type = "client_credentials"
}
$accessToken = $tokenResponse.access_token
Write-Host "✅ Got token" -ForegroundColor Green
Write-Host ""

# Register channel.subscribe (new subscriptions)
Write-Host "Registering channel.subscribe webhook..." -ForegroundColor Cyan
try {
    $sub1 = Invoke-RestMethod -Uri "https://api.twitch.tv/helix/eventsub/subscriptions" -Method POST -Headers @{
        "Authorization" = "Bearer $accessToken"
        "Client-Id" = $clientId
        "Content-Type" = "application/json"
    } -Body (@{
        type = "channel.subscribe"
        version = "1"
        condition = @{
            broadcaster_user_id = $broadcasterId
        }
        transport = @{
            method = "webhook"
            callback = "https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-eventsub-webhook"
            secret = $eventsubSecret
        }
    } | ConvertTo-Json -Depth 10)
    Write-Host "✅ Registered channel.subscribe" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed: $_" -ForegroundColor Red
}

# Register channel.subscription.message (renewals)
Write-Host "Registering channel.subscription.message webhook..." -ForegroundColor Cyan
try {
    $sub2 = Invoke-RestMethod -Uri "https://api.twitch.tv/helix/eventsub/subscriptions" -Method POST -Headers @{
        "Authorization" = "Bearer $accessToken"
        "Client-Id" = $clientId
        "Content-Type" = "application/json"
    } -Body (@{
        type = "channel.subscription.message"
        version = "1"
        condition = @{
            broadcaster_user_id = $broadcasterId
        }
        transport = @{
            method = "webhook"
            callback = "https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-eventsub-webhook"
            secret = $eventsubSecret
        }
    } | ConvertTo-Json -Depth 10)
    Write-Host "✅ Registered channel.subscription.message" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed: $_" -ForegroundColor Red
}

# Register channel.subscription.end (cancellations)
Write-Host "Registering channel.subscription.end webhook..." -ForegroundColor Cyan
try {
    $sub3 = Invoke-RestMethod -Uri "https://api.twitch.tv/helix/eventsub/subscriptions" -Method POST -Headers @{
        "Authorization" = "Bearer $accessToken"
        "Client-Id" = $clientId
        "Content-Type" = "application/json"
    } -Body (@{
        type = "channel.subscription.end"
        version = "1"
        condition = @{
            broadcaster_user_id = $broadcasterId
        }
        transport = @{
            method = "webhook"
            callback = "https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-eventsub-webhook"
            secret = $eventsubSecret
        }
    } | ConvertTo-Json -Depth 10)
    Write-Host "✅ Registered channel.subscription.end" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "✅ ALL DONE!" -ForegroundColor Green
Write-Host ""
Write-Host "Now when users subscribe/renew/cancel, Twitch will automatically notify StatusXP." -ForegroundColor Cyan
