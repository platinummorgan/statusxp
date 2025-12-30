# Google Sign-In Configuration

## Overview
This document explains how to configure Google Sign-In for the StatusXP app.

## Prerequisites
- Google Cloud Console account
- Android package name: `com.platovalabs.statusxp`
- SHA-1 fingerprint of your signing certificate

## Setup Steps

### 1. Create Google Cloud Project
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing project
3. Enable **Google+ API** (or **Google Identity** service)

### 2. Configure OAuth Consent Screen
1. Navigate to **APIs & Services** → **OAuth consent screen**
2. Choose **External** user type
3. Fill in app information:
   - App name: **StatusXP**
   - User support email: support@platovalabs.com
   - Developer contact: support@platovalabs.com
4. Add scopes (if needed): `email`, `profile`
5. Save and continue

### 3. Create OAuth 2.0 Credentials

#### Android OAuth Client ID
1. Go to **APIs & Services** → **Credentials**
2. Click **Create Credentials** → **OAuth client ID**
3. Choose **Android** as application type
4. Enter:
   - **Name**: StatusXP Android
   - **Package name**: `com.platovalabs.statusxp`
   - **SHA-1 certificate fingerprint**: (see below)

#### Get SHA-1 Fingerprint
Run this command to get your debug keystore SHA-1:
```bash
# Debug keystore (for development)
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# Release keystore (for production)
keytool -list -v -keystore "path/to/your/release.keystore" -alias your-key-alias
```

#### Web OAuth Client ID (for Supabase)
1. Create another OAuth client ID
2. Choose **Web application** as type
3. Enter:
   - **Name**: StatusXP Supabase
   - **Authorized redirect URIs**: 
     - `https://[YOUR-SUPABASE-PROJECT].supabase.co/auth/v1/callback`
4. Copy the **Client ID** - this is your `GOOGLE_SERVER_CLIENT_ID`

### 4. Configure Supabase
1. Go to your Supabase Dashboard
2. Navigate to **Authentication** → **Providers**
3. Enable **Google** provider
4. Enter:
   - **Client ID**: (Web OAuth Client ID from step 3)
   - **Client Secret**: (Web OAuth Client Secret from step 3)
5. Save

### 5. Update Android Configuration
Edit `android/app/build.gradle` and add:
```gradle
defaultConfig {
    // ... existing config ...
    
    manifestPlaceholders = [
        'appAuthRedirectScheme': 'com.platovalabs.statusxp'
    ]
}
```

### 6. Update .env File
Add your Web OAuth Client ID to `.env`:
```
GOOGLE_SERVER_CLIENT_ID=your-web-oauth-client-id.apps.googleusercontent.com
```

### 7. Rebuild the App
```bash
flutter clean
flutter pub get
flutter build appbundle --release
```

## Testing Google Sign-In

### Debug Mode
1. Ensure your debug keystore SHA-1 is registered in Google Cloud Console
2. Run the app: `flutter run`
3. Tap "Continue with Google"
4. Sign in with your Google account

### Release Mode
1. Ensure your release keystore SHA-1 is registered
2. Build release: `flutter build appbundle --release`
3. Upload to Google Play (closed testing track)
4. Download from Play Store and test

## Troubleshooting

### "API not enabled" error
- Go to Google Cloud Console
- Enable **Google+ API** or **Google Identity Services API**

### "Invalid client" error
- Check that package name matches: `com.platovalabs.statusxp`
- Verify SHA-1 fingerprint is correct
- Ensure OAuth client is created for Android (not Web)

### "Sign in failed" error
- Check Supabase Google provider is enabled
- Verify Web OAuth Client ID is correct in Supabase
- Check redirect URIs are configured correctly

### Users can't sign in on release builds
- Ensure **release keystore SHA-1** is registered
- Add both debug AND release SHA-1s to same OAuth client

## Security Notes
- Never commit `.env` file to git
- Keep OAuth credentials secure
- Use different OAuth clients for development and production
- Regularly rotate signing keys and update SHA-1 fingerprints

## Support
For issues with Google Sign-In setup, contact: support@platovalabs.com
