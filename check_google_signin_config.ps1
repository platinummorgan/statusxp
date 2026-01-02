# Quick diagnostic script for Google Sign In Error 10

Write-Host "=== Google Sign In Configuration Checker ===" -ForegroundColor Cyan
Write-Host ""

# Check if running in correct directory
if (!(Test-Path "pubspec.yaml")) {
    Write-Host "ERROR: Run this from your Flutter project root!" -ForegroundColor Red
    exit 1
}

Write-Host "1. Getting current debug keystore SHA-1..." -ForegroundColor Yellow
try {
    $debugKeystore = "$env:USERPROFILE\.android\debug.keystore"
    if (Test-Path $debugKeystore) {
        $sha1Output = keytool -list -v -keystore $debugKeystore -alias androiddebugkey -storepass android -keypass android 2>&1 | Select-String "SHA1:"
        Write-Host "   DEBUG SHA-1: $sha1Output" -ForegroundColor Green
    } else {
        Write-Host "   Debug keystore not found!" -ForegroundColor Red
    }
} catch {
    Write-Host "   Failed to get SHA-1: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "2. Checking package name in build.gradle..." -ForegroundColor Yellow
try {
    $gradleContent = Get-Content "android\app\build.gradle.kts" -Raw
    if ($gradleContent -match 'namespace\s*=\s*"([^"]+)"') {
        Write-Host "   Package: $($matches[1])" -ForegroundColor Green
        if ($matches[1] -ne "com.platovalabs.statusxp") {
            Write-Host "   WARNING: Should be com.platovalabs.statusxp!" -ForegroundColor Red
        }
    }
} catch {
    Write-Host "   Could not read build.gradle" -ForegroundColor Red
}

Write-Host ""
Write-Host "3. Checking for release keystore..." -ForegroundColor Yellow
$keystorePath = "android\key.properties"
if (Test-Path $keystorePath) {
    Write-Host "   Release keystore configured (key.properties exists)" -ForegroundColor Green
} else {
    Write-Host "   No release keystore found (only debug available)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== Action Items ===" -ForegroundColor Cyan
Write-Host "1. Copy the SHA-1 above"
Write-Host "2. Go to Google Cloud Console → Credentials"
Write-Host "3. Edit your Android OAuth Client"
Write-Host "4. Make sure the SHA-1 is registered"
Write-Host "5. Package name matches: com.platovalabs.statusxp"
Write-Host ""
Write-Host "If you're testing a RELEASE build, you need the RELEASE keystore SHA-1!" -ForegroundColor Yellow
