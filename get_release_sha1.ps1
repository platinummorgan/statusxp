# Get Release Keystore SHA-1 for Google Cloud Console

Write-Host "=== Getting Release Keystore SHA-1 ===" -ForegroundColor Cyan
Write-Host ""

# Read key.properties to get keystore info
$keyPropsFile = "android\key.properties"
if (!(Test-Path $keyPropsFile)) {
    Write-Host "ERROR: key.properties not found!" -ForegroundColor Red
    exit 1
}

$keyProps = @{}
Get-Content $keyPropsFile | ForEach-Object {
    if ($_ -match '^\s*([^=]+)\s*=\s*(.+)\s*$') {
        $keyProps[$matches[1]] = $matches[2]
    }
}

$keystorePath = $keyProps['storeFile']
$keystorePassword = $keyProps['storePassword']
$keyAlias = $keyProps['keyAlias']
$keyPassword = $keyProps['keyPassword']

if (!$keystorePath) {
    Write-Host "ERROR: Could not read keystore path from key.properties!" -ForegroundColor Red
    exit 1
}

# Resolve relative path
$fullKeystorePath = Join-Path "android" $keystorePath

if (!(Test-Path $fullKeystorePath)) {
    Write-Host "ERROR: Keystore not found at: $fullKeystorePath" -ForegroundColor Red
    exit 1
}

Write-Host "Keystore: $fullKeystorePath" -ForegroundColor Yellow
Write-Host "Alias: $keyAlias" -ForegroundColor Yellow
Write-Host ""

try {
    Write-Host "Getting SHA-1 fingerprint..." -ForegroundColor Yellow
    $output = keytool -list -v -keystore $fullKeystorePath -alias $keyAlias -storepass $keystorePassword -keypass $keyPassword 2>&1
    
    $sha1Line = $output | Select-String "SHA1:"
    $sha256Line = $output | Select-String "SHA256:"
    
    Write-Host ""
    Write-Host "=== COPY THESE TO GOOGLE CLOUD CONSOLE ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "RELEASE SHA-1:" -ForegroundColor Cyan
    Write-Host $sha1Line -ForegroundColor White
    Write-Host ""
    Write-Host "RELEASE SHA-256 (optional, for extra security):" -ForegroundColor Cyan  
    Write-Host $sha256Line -ForegroundColor White
    Write-Host ""
    Write-Host "=== STEPS ===" -ForegroundColor Yellow
    Write-Host "1. Go to: https://console.cloud.google.com/apis/credentials"
    Write-Host "2. Find your Android OAuth Client (for com.statusxp.statusxp)"
    Write-Host "3. Click Edit"
    Write-Host "4. Add the SHA-1 above if it's not already there"
    Write-Host "5. Make sure package name is: com.statusxp.statusxp"
    Write-Host "6. Save and wait 5-10 minutes for Google to update"
    Write-Host ""
} catch {
    Write-Host "ERROR: Failed to get SHA-1: $_" -ForegroundColor Red
    Write-Host "Check that your key.properties passwords are correct" -ForegroundColor Yellow
}
