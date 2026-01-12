# Setup script for connecting psql to Supabase
# Run this once to configure your database connection

Write-Host "=== Supabase PostgreSQL Setup ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "To get your connection string:" -ForegroundColor Yellow
Write-Host "1. Go to https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/settings/database"
Write-Host "2. Scroll to 'Connection string' section"
Write-Host "3. Select 'URI' tab"
Write-Host "4. Copy the connection string (it starts with postgresql://)"
Write-Host "5. Replace [YOUR-PASSWORD] with your database password"
Write-Host ""

$connectionString = Read-Host "Paste your Supabase connection string here"

if ($connectionString) {
    # Save to environment variable for this session
    $env:SUPABASE_DB_URL = $connectionString
    
    # Save to .env file for persistence
    if (Test-Path ".env") {
        $envContent = Get-Content ".env" -Raw
        if ($envContent -match "SUPABASE_DB_URL=") {
            $envContent = $envContent -replace "SUPABASE_DB_URL=.*", "SUPABASE_DB_URL=$connectionString"
        } else {
            $envContent += "`nSUPABASE_DB_URL=$connectionString"
        }
        Set-Content ".env" $envContent
    } else {
        Set-Content ".env" "SUPABASE_DB_URL=$connectionString"
    }
    
    Write-Host ""
    Write-Host "✅ Connection string saved!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Testing connection..." -ForegroundColor Cyan
    
    # Test the connection
    psql $connectionString -c "SELECT current_database(), current_user;"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Connection successful!" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now run queries like:" -ForegroundColor Cyan
        Write-Host "psql `$env:SUPABASE_DB_URL -c `"SELECT * FROM user_ai_credits LIMIT 5;`"" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "❌ Connection failed. Please check your connection string and password." -ForegroundColor Red
    }
} else {
    Write-Host "❌ No connection string provided." -ForegroundColor Red
}
