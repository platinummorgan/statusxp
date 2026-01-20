@echo off
echo Getting SHA-1 fingerprint for StatusXP app...
echo.

echo === DEBUG KEYSTORE (for development) ===
echo Location: %USERPROFILE%\.android\debug.keystore
echo.
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android | findstr SHA1

echo.
echo === RELEASE KEYSTORE (if you have one) ===
if exist "android\key.properties" (
    echo Found key.properties file
    type android\key.properties
) else (
    echo No release keystore configured
)

echo.
echo Copy the SHA1 fingerprint above and add it to:
echo 1. Go to https://console.developers.google.com/
echo 2. Select your StatusXP project
echo 3. Go to Credentials ^> OAuth 2.0 Client IDs
echo 4. Edit your Android client
echo 5. Make sure package name is: com.statusxp.statusxp
echo 6. Add the SHA1 fingerprint shown above