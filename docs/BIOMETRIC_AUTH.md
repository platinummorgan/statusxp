# Biometric Authentication with Refresh Tokens

## Overview

StatusXP implements secure biometric authentication using refresh tokens stored in OS-level encrypted storage (Android Keystore / iOS Keychain). This approach provides secure, convenient re-authentication without storing user passwords.

## Architecture

### Key Components

1. **SecureTokenStorage** - Manages encrypted token storage using OS-level security
2. **BiometricAuthService** - Handles biometric authentication prompts and token management
3. **AuthService** - Provides token refresh and session restoration methods
4. **BiometricLoginScreen** - UI for biometric authentication flow
5. **AuthGate** - Entry point that determines which screen to show based on auth state

### Security Features

- ✅ **No Password Storage** - Only refresh tokens are stored, never passwords
- ✅ **OS-Level Encryption** - Uses Android Keystore and iOS Keychain for hardware-backed encryption
- ✅ **Device-Bound** - Tokens are encrypted per-device and can only be accessed by this app
- ✅ **Biometric Gating** - Tokens can only be retrieved after successful biometric authentication
- ✅ **Server-Side Invalidation** - Tokens are invalidated on server when user logs out
- ✅ **Automatic Expiration** - Refresh tokens expire after 30-90 days, requiring full re-authentication

## Flow Diagrams

### First-Time Sign In Flow

```
1. User signs in with email/password or OAuth
2. AuthService receives access token + refresh token
3. App offers to enable biometric authentication
4. If user accepts:
   a. Refresh token is stored in SecureTokenStorage (encrypted by OS)
   b. Biometric flag is set to enabled
5. User proceeds to main app
```

### Biometric Re-Authentication Flow

```
1. App launches
2. AuthGate checks for stored refresh token
3. If token exists and not expired:
   a. BiometricLoginScreen is shown
   b. Biometric prompt appears immediately
4. User authenticates with fingerprint/face
5. On success:
   a. Refresh token is retrieved from secure storage
   b. Token is sent to Supabase for validation
   c. New access token + refresh token are returned
   d. New refresh token is stored (replacing old one)
6. User is signed in automatically
```

### Sign Out Flow

```
1. User triggers sign out
2. AuthService.signOut() is called
3. Supabase invalidates the refresh token on server
4. SecureTokenStorage clears local token
5. User is redirected to sign-in screen
6. Stored refresh token is now useless (invalidated on server)
```

## Implementation Guide

### 1. Enable Biometric Auth After Sign-In

```dart
import 'package:statusxp/data/auth/biometric_auth_integration.dart';

// In your sign-in screen, after successful authentication:
final authService = ref.read(authServiceProvider);
final biometricService = BiometricAuthService();
final integration = BiometricAuthIntegration(authService, biometricService);

// Option A: Enable silently
final enabled = await integration.enableBiometricAuth();
if (enabled) {
  print('Biometric auth enabled!');
}

// Option B: Prompt user with dialog
await integration.promptEnableBiometricAuth(context);

// Option C: Using extension method
await authService.enableBiometric();
```

### 2. Disable Biometric Auth

```dart
// In settings or sign-out flow:
final authService = ref.read(authServiceProvider);
await authService.disableBiometric();
```

### 3. Sign Out (with Token Invalidation)

```dart
// Regular sign out - automatically invalidates refresh token
final authService = ref.read(authServiceProvider);
await authService.signOut();

// Also clear biometric token locally
final biometricService = BiometricAuthService();
await biometricService.clearRefreshToken();
```

### 4. Check Biometric Availability

```dart
final biometricService = BiometricAuthService();

// Check if device supports biometrics
final isAvailable = await biometricService.isBiometricAvailable();

// Get available biometric types (fingerprint, face, etc.)
final types = await biometricService.getAvailableBiometrics();

// Get user-friendly description
final description = await biometricService.getBiometricTypesDescription();
// e.g., "Fingerprint, Face ID"
```

## Server-Side Token Management

Supabase automatically handles refresh token management:

### Token Lifecycle

- **Access Token**: Short-lived (1 hour), used for API requests
- **Refresh Token**: Long-lived (30-90 days), used to get new access tokens
- **Auto-Refresh**: Supabase client automatically refreshes before expiry
- **Invalidation**: `signOut()` revokes the refresh token on server

### Security Considerations

1. **Expiration**: Refresh tokens expire after 30-90 days (configurable in Supabase)
2. **Rotation**: Each token refresh issues a new refresh token (old one becomes invalid)
3. **Revocation**: Sign out immediately invalidates the refresh token
4. **One-Time Use**: Each refresh token can only be used once

## Best Practices

### ✅ DO

- Enable biometric auth after successful sign-in
- Clear tokens when user disables biometric auth
- Clear tokens on sign out
- Update stored refresh token after each successful restoration
- Handle token expiration gracefully (redirect to sign-in)
- Check biometric availability before offering the feature

### ❌ DON'T

- Store passwords in secure storage (use refresh tokens instead)
- Keep expired tokens
- Reuse the same refresh token multiple times
- Skip server-side token invalidation on sign out
- Assume biometrics are available on all devices

## Platform-Specific Notes

### Android (Keystore)

- Uses `encryptedSharedPreferences` for extra security
- Supports fingerprint and face unlock
- Requires device lock screen (PIN/pattern/password) to be set
- Hardware-backed encryption on modern devices

### iOS (Keychain)

- Uses `first_unlock_this_device` accessibility level
- Supports Touch ID and Face ID
- Requires device passcode to be set
- Always hardware-backed encryption

## Troubleshooting

### Token Expired

If the refresh token expires (after 30-90 days):
1. BiometricLoginScreen shows error message
2. User is redirected to full sign-in flow
3. After sign-in, biometric auth can be re-enabled

### Biometric Authentication Failed

If biometric prompt is cancelled or fails:
1. User sees error message with retry option
2. User can choose "Sign in with password" instead
3. Stored token remains (not cleared)

### Token Invalid After Sign Out

If user tries to use stored token after signing out:
1. Server rejects the invalidated refresh token
2. BiometricLoginScreen shows "Session could not be restored"
3. User is redirected to full sign-in flow

## Testing

### Test Biometric Flow

```dart
// 1. Sign in with email/password
// 2. Enable biometric auth
// 3. Sign out
// 4. Restart app
// 5. Should see BiometricLoginScreen
// 6. Authenticate with biometric
// 7. Should be signed in automatically
```

### Test Token Expiration

```dart
// Manually expire the stored token for testing:
final biometricService = BiometricAuthService();
await biometricService.storeRefreshToken(
  refreshToken: 'test_token',
  userId: 'test_user',
  expiresAt: DateTime.now().subtract(Duration(days: 1)), // Already expired
);
// Restart app - should redirect to sign-in
```

### Test Sign Out Invalidation

```dart
// 1. Sign in and enable biometric
// 2. Sign out properly (invalidates token on server)
// 3. Restart app
// 4. BiometricLoginScreen appears
// 5. Authenticate with biometric
// 6. Should show "Session could not be restored"
// 7. Redirected to sign-in screen
```

## Migration from Password-Based Flow

If you're currently storing passwords for biometric auth, migrate to refresh tokens:

```dart
// Old approach (DEPRECATED)
await biometricService.storeCredentials(email, password);

// New approach (RECOMMENDED)
final refreshToken = authService.refreshToken;
final expiry = authService.refreshTokenExpiry;
final userId = authService.currentUser?.id;

if (refreshToken != null && expiry != null && userId != null) {
  await biometricService.storeRefreshToken(
    refreshToken: refreshToken,
    userId: userId,
    expiresAt: expiry,
  );
}
```

## References

- [Android Keystore System](https://developer.android.com/training/articles/keystore)
- [iOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- [Local Auth Package](https://pub.dev/packages/local_auth)
