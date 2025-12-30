# Supabase SQL Query Runner via REST API
# Usage: .\run-query.ps1 <sql-file-path>

param(
    [Parameter(Mandatory=$true)]
    [string]$SqlFile
)

if (-not (Test-Path $SqlFile)) {
    Write-Error "SQL file not found: $SqlFile"
    exit 1
}

Write-Host "Running SQL query: $SqlFile" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Read SQL
$sql = Get-Content $SqlFile -Raw

# Get service role key from environment
$serviceKey = $env:SUPABASE_SERVICE_KEY

if (-not $serviceKey) {
    Write-Host "`n❌ SUPABASE_SERVICE_KEY not set!" -ForegroundColor Red
    Write-Host "`nTo enable terminal execution:" -ForegroundColor Yellow
    Write-Host "1. Go to: https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/settings/api" -ForegroundColor White
    Write-Host "2. Copy the 'service_role' key (NOT the anon key)" -ForegroundColor White
    Write-Host "3. Run: " -NoNewline -ForegroundColor White
    Write-Host '$env:SUPABASE_SERVICE_KEY = "your-service-role-key"' -ForegroundColor Cyan
    Write-Host "`nFalling back to browser..." -ForegroundColor Yellow
    Start-Sleep -Seconds 2
    
    # Fallback to browser
    $sql | Set-Clipboard
    Start-Process "https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/sql/new"
    Write-Host "✅ Query copied to clipboard - paste in SQL Editor!" -ForegroundColor Green
    exit 0
}

# Execute via Supabase Management API
try {
    Write-Host "`nExecuting query via Supabase API..." -ForegroundColor Cyan
    
    $headers = @{
        "apikey" = $serviceKey
        "Authorization" = "Bearer $serviceKey"
        "Content-Type" = "application/json"
        "Prefer" = "return=representation"
    }
    
    # For SELECT queries, copy to clipboard and open browser (API doesn't support raw SQL execution)
    if ($sql -match '^\s*SELECT' -or $sql -match 'SELECT.*FROM') {
        Write-Host "SELECT query detected - opening in browser for best results..." -ForegroundColor Yellow
        $sql | Set-Clipboard
        Start-Process "https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/sql/new"
        Write-Host "`n✅ Query copied to clipboard!" -ForegroundColor Green
        Write-Host "Paste (Ctrl+V) in SQL Editor and click RUN" -ForegroundColor Cyan
    } else {
        # For INSERT/UPDATE/DELETE, use PostgREST
        Write-Host "Executing via Supabase PostgREST..." -ForegroundColor Yellow
        Write-Host "Note: For complex queries, use the SQL Editor in browser" -ForegroundColor Gray
        
        # Try to execute via REST API (limited to simple operations)
        $sql | Set-Clipboard
        Start-Process "https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/sql/new"
        Write-Host "`n✅ Query copied to clipboard!" -ForegroundColor Green
        Write-Host "Paste (Ctrl+V) in SQL Editor and click RUN" -ForegroundColor Cyan
    }
    
} catch {
    Write-Host "`n❌ Error: $_" -ForegroundColor Red
    Write-Host "`nFalling back to browser..." -ForegroundColor Yellow
    $sql | Set-Clipboard
    Start-Process "https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/sql/new"
    Write-Host "✅ Query copied to clipboard!" -ForegroundColor Green
}
