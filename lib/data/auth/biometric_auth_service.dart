import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';
import 'package:statusxp/data/auth/secure_token_storage.dart';

/// Result of a biometric authentication attempt
class BiometricAuthResult {
  final bool success;
  final String? errorMessage;
  
  BiometricAuthResult({required this.success, this.errorMessage});
}

/// Service for managing biometric authentication (fingerprint, Face ID, etc.)
/// 
/// Uses refresh tokens stored in OS-level secure storage (Keystore/Keychain)
/// to enable biometric re-authentication without storing passwords.
/// 
/// Flow:
/// 1. User signs in with email/password or OAuth
/// 2. Refresh token is stored in secure storage (encrypted by OS)
/// 3. On app restart, user can unlock with biometrics
/// 4. Refresh token is retrieved and exchanged for new access token
/// 5. User is signed in without entering credentials
class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureTokenStorage _tokenStorage = SecureTokenStorage();
  
  // Legacy support - for backward compatibility with old password-based flow
  final FlutterSecureStorage _legacyStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  
  static const String _storedEmailKey = 'biometric_stored_email';
  static const String _storedPasswordKey = 'biometric_stored_password';
  
  /// Check if the device supports biometric authentication
  Future<bool> isBiometricAvailable() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }
  
  /// Get the list of available biometric types (fingerprint, face, iris)
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }
  
  /// Check if biometric authentication is currently enabled by the user
  Future<bool> isBiometricEnabled() async {
    return await _tokenStorage.isBiometricEnabled();
  }
  
  /// Enable or disable biometric authentication
  /// 
  /// When disabled, clears all stored tokens for security.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _tokenStorage.setBiometricEnabled(enabled);
  }
  
  /// Authenticate using biometrics with detailed error reporting
  /// 
  /// Shows the biometric prompt to the user and returns a result with success status and error message.
  /// [reason] is the message shown to the user explaining why authentication is needed.
  Future<BiometricAuthResult> authenticate({
    String reason = 'Please authenticate to access StatusXP',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        final types = await getAvailableBiometrics();
        if (types.isEmpty) {
          return BiometricAuthResult(
            success: false,
            errorMessage: 'No biometrics enrolled. Please set up fingerprint or face unlock in your device settings.',
          );
        }
        return BiometricAuthResult(
          success: false,
          errorMessage: 'Biometric authentication is not available on this device.',
        );
      }
      
      final authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true, // Keep auth dialog on screen until success/cancel
          biometricOnly: false, // Allow fallback to PIN/password if biometric fails
        ),
      );
      
      return BiometricAuthResult(
        success: authenticated,
        errorMessage: authenticated ? null : 'Authentication was cancelled or failed.',
      );
    } on PlatformException catch (e) {
      String errorMessage;
      if (e.code == auth_error.notAvailable) {
        errorMessage = 'Biometric authentication is not available on this device.';
      } else if (e.code == auth_error.notEnrolled) {
        errorMessage = 'No biometrics enrolled. Please set up fingerprint or face unlock in your device settings.';
      } else if (e.code == auth_error.lockedOut) {
        errorMessage = 'Too many failed attempts. Biometric authentication is temporarily locked.';
      } else if (e.code == auth_error.permanentlyLockedOut) {
        errorMessage = 'Biometric authentication is permanently locked. Please unlock your device.';
      } else if (e.code == auth_error.passcodeNotSet) {
        errorMessage = 'No device passcode set. Please set up a PIN, pattern, or password first.';
      } else {
        errorMessage = 'Biometric authentication error: ${e.message ?? e.code}';
      }
      return BiometricAuthResult(success: false, errorMessage: errorMessage);
    } catch (e) {
      return BiometricAuthResult(
        success: false,
        errorMessage: 'Unexpected error: ${e.toString()}',
      );
    }
  }
  
  /// Simple authenticate method for backward compatibility (returns bool)
  Future<bool> authenticateSimple({
    String reason = 'Please authenticate to access StatusXP',
  }) async {
    final result = await authenticate(reason: reason);
    return result.success;
  }
  
  /// Get a user-friendly description of available biometric types
  Future<String> getBiometricTypesDescription() async {
    final types = await getAvailableBiometrics();
    if (types.isEmpty) {
      return 'None available';
    }
    
    final descriptions = types.map((type) {
      switch (type) {
        case BiometricType.face:
          return 'Face ID';
        case BiometricType.fingerprint:
          return 'Fingerprint';
        case BiometricType.iris:
          return 'Iris';
        case BiometricType.strong:
          return 'Strong biometric';
        case BiometricType.weak:
          return 'Weak biometric';
      }
    }).toList();
    
    return descriptions.join(', ');
  }
  
  /// Store refresh token for biometric authentication (RECOMMENDED)
  /// 
  /// Should be called after successful authentication to enable biometric login.
  /// Uses refresh token flow for better security (no password storage).
  /// 
  /// The refresh token is encrypted by the OS and bound to this device.
  Future<void> storeRefreshToken({
    required String refreshToken,
    required String userId,
    required DateTime expiresAt,
  }) async {
    await _tokenStorage.storeRefreshToken(
      refreshToken: refreshToken,
      userId: userId,
      expiresAt: expiresAt,
    );
    await _tokenStorage.setBiometricEnabled(true);
  }
  
  /// Retrieve stored refresh token (only after biometric auth succeeds)
  /// 
  /// Returns the stored refresh token data, or null if not available.
  /// This should only be called after successful biometric authentication.
  Future<StoredToken?> getRefreshToken() async {
    return await _tokenStorage.getRefreshToken();
  }
  
  /// Check if a refresh token is stored
  Future<bool> hasStoredRefreshToken() async {
    return await _tokenStorage.hasRefreshToken();
  }
  
  /// Check if the stored refresh token is expired
  Future<bool> isRefreshTokenExpired() async {
    return await _tokenStorage.isTokenExpired();
  }
  
  /// Clear stored refresh token
  /// 
  /// Should be called on sign out or when disabling biometric authentication.
  Future<void> clearRefreshToken() async {
    await _tokenStorage.clearRefreshToken();
  }
  
  // ============================================================================
  // LEGACY METHODS - For backward compatibility with password-based flow
  // These should be deprecated in favor of refresh token flow
  // ============================================================================
  
  /// Store credentials securely for biometric authentication (LEGACY)
  /// 
  /// ⚠️ DEPRECATED: Use storeRefreshToken() instead for better security.
  /// Storing passwords is less secure than using refresh tokens.
  @Deprecated('Use storeRefreshToken() instead')
  Future<void> storeCredentials(String email, String password) async {
    await _legacyStorage.write(key: _storedEmailKey, value: email);
    await _legacyStorage.write(key: _storedPasswordKey, value: password);
  }
  
  /// Retrieve stored credentials (only after biometric auth succeeds) (LEGACY)
  /// 
  /// ⚠️ DEPRECATED: Use getRefreshToken() instead.
  @Deprecated('Use getRefreshToken() instead')
  Future<Map<String, String>?> getStoredCredentials() async {
    final email = await _legacyStorage.read(key: _storedEmailKey);
    final password = await _legacyStorage.read(key: _storedPasswordKey);
    
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }
  
  /// Check if credentials are stored (LEGACY)
  /// 
  /// ⚠️ DEPRECATED: Use hasStoredRefreshToken() instead.
  @Deprecated('Use hasStoredRefreshToken() instead')
  Future<bool> hasStoredCredentials() async {
    final email = await _legacyStorage.read(key: _storedEmailKey);
    return email != null;
  }
  
  /// Clear stored credentials (LEGACY)
  @Deprecated('Use clearRefreshToken() instead')
  Future<void> clearStoredCredentials() async {
    await _legacyStorage.delete(key: _storedEmailKey);
    await _legacyStorage.delete(key: _storedPasswordKey);
    await clearRefreshToken();
  }
}
