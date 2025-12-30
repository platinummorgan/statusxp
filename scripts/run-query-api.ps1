# Direct SQL Query via Supabase REST API
param(
    [Parameter(Mandatory=$true)]
    [string]$SqlFile
)

$sql = Get-Content $SqlFile -Raw
$supabaseUrl = "https://ksriqcmumjkemtfjuedm.supabase.co"
$serviceKey = $env:SUPABASE_SERVICE_KEY

if (-not $serviceKey) {
    Write-Host "Error: SUPABASE_SERVICE_KEY environment variable not set" -ForegroundColor Red
    Write-Host "Get your service role key from: Supabase Dashboard > Project Settings > API > service_role key" -ForegroundColor Yellow
    exit 1
}

Write-Host "Executing SQL via Supabase API..." -ForegroundColor Cyan

$headers = @{
    "apikey" = $serviceKey
    "Authorization" = "Bearer $serviceKey"
    "Content-Type" = "application/json"
}

$body = @{
    query = $sql
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/rpc/exec_sql" -Method Post -Headers $headers -Body $body
    $response | ConvertTo-Json -Depth 10 | Write-Host
} catch {
    Write-Error "Failed: $_"
}
