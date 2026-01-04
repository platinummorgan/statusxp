import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing biometric authentication (fingerprint, Face ID, etc.)
/// 
/// Provides secure local authentication using device biometrics to unlock the app.
class BiometricAuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _biometricEnabledKey = 'biometric_auth_enabled';
  
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
  
  /// Authenticate using biometrics
  /// 
  /// Shows the biometric prompt to the user and returns true if authentication succeeds.
  /// [reason] is the message shown to the user explaining why authentication is needed.
  Future<bool> authenticate({
    String reason = 'Please authenticate to access StatusXP',
  }) async {
    try {
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }
      
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true, // Keep auth dialog on screen until success/cancel
          biometricOnly: false, // Allow fallback to PIN/password if biometric fails
        ),
      );
    } catch (e) {
      return false;
    }
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
}
