import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart';

/// Result of a biometric authentication attempt
class BiometricAuthResult {
  final bool success;
  final String? errorMessage;
  
  BiometricAuthResult({required this.success, this.errorMessage});
}

/// Service for managing biometric authentication (fingerprint, Face ID, etc.)
/// 
/// Provides secure local authentication using device biometrics to sign in.
/// Stores encrypted credentials in secure storage for full authentication.
class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  
  static const String _biometricEnabledKey = 'biometric_auth_enabled';
  static const String _storedEmailKey = 'biometric_stored_email';
  static const String _storedPasswordKey = 'biometric_stored_password';
  static const String _storedSessionKey = 'biometric_stored_session';
  
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
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }
  
  /// Enable or disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
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
  
  /// Store credentials securely for biometric authentication
  /// Should be called after successful email/password sign-in
  Future<void> storeCredentials(String email, String password) async {
    await _secureStorage.write(key: _storedEmailKey, value: email);
    await _secureStorage.write(key: _storedPasswordKey, value: password);
  }
  
  /// Retrieve stored credentials (only after biometric auth succeeds)
  Future<Map<String, String>?> getStoredCredentials() async {
    final email = await _secureStorage.read(key: _storedEmailKey);
    final password = await _secureStorage.read(key: _storedPasswordKey);
    
    if (email != null && password != null) {
      return {'email': email, 'password': password};
    }
    return null;
  }
  
  /// Check if credentials are stored
  Future<bool> hasStoredCredentials() async {
    final email = await _secureStorage.read(key: _storedEmailKey);
    return email != null;
  }
  
  /// Clear stored credentials (on sign out or disable biometric)
  Future<void> clearStoredCredentials() async {
    await _secureStorage.delete(key: _storedEmailKey);
    await _secureStorage.delete(key: _storedPasswordKey);
    await _secureStorage.delete(key: _storedSessionKey);
  }

  /// Clear only the stored OAuth session data
  Future<void> clearStoredSession() async {
    await _secureStorage.delete(key: _storedSessionKey);
  }
  
  /// Store OAuth session data securely for biometric authentication
  /// Should be called after successful OAuth sign-in (Google/Apple)
  Future<void> storeSession(String sessionJson) async {
    await _secureStorage.write(key: _storedSessionKey, value: sessionJson);
  }
  
  /// Retrieve stored OAuth session data (only after biometric auth succeeds)
  Future<String?> getStoredSession() async {
    return await _secureStorage.read(key: _storedSessionKey);
  }
  
  /// Check if session is stored
  Future<bool> hasStoredSession() async {
    final session = await _secureStorage.read(key: _storedSessionKey);
    return session != null;
  }
}
