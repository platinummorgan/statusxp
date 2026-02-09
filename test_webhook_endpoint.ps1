# Test webhook endpoint
$testPayload = @{
    challenge = "test-challenge-123"
    subscription = @{
        type = "channel.subscribe"
    }
} | ConvertTo-Json

$headers = @{
    "Content-Type" = "application/json"
    "Twitch-Eventsub-Message-Id" = "test-id"
    "Twitch-Eventsub-Message-Timestamp" = "2021-11-16T10:11:12.123Z"
    "Twitch-Eventsub-Message-Type" = "webhook_callback_verification"
    "Twitch-Eventsub-Message-Signature" = "sha256=test"
}

Write-Host "Testing webhook endpoint..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest `
        -Uri "https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-eventsub-webhook" `
        -Method POST `
        -Headers $headers `
        -Body $testPayload

    Write-Host "✅ Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response: $($response.Content)" -ForegroundColor Yellow
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $responseBody = $reader.ReadToEnd()
        Write-Host "Response Body: $responseBody" -ForegroundColor Yellow
    }
}
