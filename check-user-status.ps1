# Check user premium and profile status
param(
    [string]$UserId = "de924030-3ade-40ae-ae87-f9f39d55750f"
)

$serviceKey = $env:SUPABASE_SERVICE_ROLE_KEY
$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg5Mzc4MDMsImV4cCI6MjA4NDI5NzgwM30.5U4XicufCRFgS8_-aKv9fQ06OQ8GutamGgoirNjp-u8"

if (-not $serviceKey) {
    Write-Host "Error: SUPABASE_SERVICE_ROLE_KEY not set" -ForegroundColor Red
    exit 1
}

$headers = @{
    "apikey" = $anonKey
    "Authorization" = "Bearer $serviceKey"
}

Write-Host "Checking status for user: $UserId" -ForegroundColor Cyan
Write-Host ""

# Check profile
Write-Host "=== PROFILE ===" -ForegroundColor Yellow
try {
    $profile = Invoke-RestMethod `
        -Uri "https://ksriqcmumjkemtfjuedm.supabase.co/rest/v1/profiles?id=eq.$UserId&select=display_name,twitch_username,twitch_user_id" `
        -Headers $headers
    
    if ($profile.Count -gt 0) {
        $profile | Format-List
    } else {
        Write-Host "User not found" -ForegroundColor Red
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== PREMIUM STATUS ===" -ForegroundColor Yellow
try {
    $premium = Invoke-RestMethod `
        -Uri "https://ksriqcmumjkemtfjuedm.supabase.co/rest/v1/user_premium_status?user_id=eq.$UserId&select=*" `
        -Headers $headers
    
    if ($premium.Count -gt 0) {
        $premium | Format-List
        Write-Host ""
        if ($premium[0].is_premium) {
            Write-Host "✅ User HAS Premium" -ForegroundColor Green
            Write-Host "   Source: $($premium[0].premium_source)" -ForegroundColor Cyan
            Write-Host "   Expires: $($premium[0].premium_expires_at)" -ForegroundColor Cyan
        } else {
            Write-Host "❌ User does NOT have premium" -ForegroundColor Red
        }
    } else {
        Write-Host "No premium status record found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
