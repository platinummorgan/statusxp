import 'package:flutter/material.dart';
import 'package:statusxp/data/auth/auth_service.dart';
import 'package:statusxp/data/auth/biometric_auth_service.dart';

/// Helper class to integrate biometric authentication into your app's sign-in flow
/// 
/// This provides a simple way to enable biometric authentication after a user
/// successfully signs in with email/password or OAuth (Google/Apple).
class BiometricAuthIntegration {
  final AuthService _authService;
  final BiometricAuthService _biometricService;
  
  BiometricAuthIntegration(this._authService, this._biometricService);
  
  /// Enable biometric authentication after successful sign-in
  /// 
  /// Call this method after the user successfully signs in to store their
  /// refresh token securely for biometric re-authentication.
  /// 
  /// Returns true if biometric auth was successfully enabled, false otherwise.
  /// 
  /// Example usage:
  /// ```dart
  /// // After successful sign-in
  /// final authService = ref.read(authServiceProvider);
  /// final biometricService = ref.read(biometricAuthServiceProvider);
  /// final integration = BiometricAuthIntegration(authService, biometricService);
  /// 
  /// final enabled = await integration.enableBiometricAuth();
  /// if (enabled) {
  ///   print('Biometric auth enabled!');
  /// }
  /// ```
  Future<bool> enableBiometricAuth() async {
    try {
      // Check if biometrics are available on this device
      final isAvailable = await _biometricService.isBiometricAvailable();
      if (!isAvailable) {
        return false;
      }
      
      // Get the current session's refresh token
      final refreshToken = _authService.refreshToken;
      final expiry = _authService.refreshTokenExpiry;
      final userId = _authService.currentUser?.id;
      
      if (refreshToken == null || expiry == null || userId == null) {
        return false;
      }
      
      // Store the refresh token securely
      await _biometricService.storeRefreshToken(
        refreshToken: refreshToken,
        userId: userId,
        expiresAt: expiry,
      );
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Disable biometric authentication and clear stored tokens
  /// 
  /// Call this when the user wants to disable biometric authentication
  /// or when signing out.
  Future<void> disableBiometricAuth() async {
    await _biometricService.clearRefreshToken();
    await _biometricService.setBiometricEnabled(false);
  }
  
  /// Check if biometric authentication is enabled
  Future<bool> isBiometricAuthEnabled() async {
    return await _biometricService.isBiometricEnabled();
  }
  
  /// Prompt user to enable biometric authentication after sign-in
  /// 
  /// Shows a dialog asking the user if they want to enable biometric auth.
  /// Returns true if user enabled it, false otherwise.
  /// 
  /// Example usage:
  /// ```dart
  /// // After successful sign-in
  /// await integration.promptEnableBiometricAuth(context);
  /// ```
  Future<bool> promptEnableBiometricAuth(context) async {
    // Check if biometrics are available
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (!isAvailable) {
      return false;
    }
    
    // Check if already enabled
    final alreadyEnabled = await _biometricService.isBiometricEnabled();
    if (alreadyEnabled) {
      return true;
    }
    
    // Show dialog
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enable Biometric Login?'),
        content: const Text(
          'Would you like to use fingerprint or face recognition to sign in next time?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not now'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      return await enableBiometricAuth();
    }
    
    return false;
  }
}

/// Extension on AuthService to easily enable biometric authentication
extension BiometricAuthExtension on AuthService {
  /// Enable biometric authentication for the current user
  /// 
  /// Returns true if successful, false otherwise.
  Future<bool> enableBiometric() async {
    final biometricService = BiometricAuthService();
    final integration = BiometricAuthIntegration(this, biometricService);
    return await integration.enableBiometricAuth();
  }
  
  /// Disable biometric authentication
  Future<void> disableBiometric() async {
    final biometricService = BiometricAuthService();
    final integration = BiometricAuthIntegration(this, biometricService);
    await integration.disableBiometricAuth();
  }
}
