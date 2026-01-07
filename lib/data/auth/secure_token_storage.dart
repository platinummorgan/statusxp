import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for authentication tokens using OS-level encryption
/// 
/// Uses Android Keystore and iOS Keychain to securely store refresh tokens
/// that can be unlocked with biometric authentication.
/// 
/// This implementation follows the recommended pattern:
/// 1. Store only refresh tokens, not access tokens
/// 2. Tokens are encrypted by OS and bound to the device
/// 3. Biometric authentication required to retrieve tokens
/// 4. Tokens are invalidated on server when user logs out
class SecureTokenStorage {
  // Use encrypted shared preferences on Android for extra security
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );
  
  // Storage keys
  static const String _refreshTokenKey = 'auth_refresh_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _tokenExpiryKey = 'auth_token_expiry';
  static const String _biometricEnabledKey = 'biometric_enabled';
  
  /// Store the refresh token securely
  /// 
  /// Should be called after successful authentication to enable biometric login.
  /// The token will be encrypted by the OS and can only be retrieved by this app
  /// on this specific device.
  Future<void> storeRefreshToken({
    required String refreshToken,
    required String userId,
    required DateTime expiresAt,
  }) async {
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _tokenExpiryKey, value: expiresAt.toIso8601String());
  }
  
  /// Retrieve the stored refresh token
  /// 
  /// Should only be called AFTER successful biometric authentication.
  /// Returns null if no token is stored.
  Future<StoredToken?> getRefreshToken() async {
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    final userId = await _storage.read(key: _userIdKey);
    final expiryStr = await _storage.read(key: _tokenExpiryKey);
    
    if (refreshToken == null || userId == null || expiryStr == null) {
      return null;
    }
    
    return StoredToken(
      refreshToken: refreshToken,
      userId: userId,
      expiresAt: DateTime.parse(expiryStr),
    );
  }
  
  /// Check if a refresh token is stored
  Future<bool> hasRefreshToken() async {
    final token = await _storage.read(key: _refreshTokenKey);
    return token != null;
  }
  
  /// Check if stored token is expired
  /// 
  /// Returns true if token is expired or no token is stored.
  Future<bool> isTokenExpired() async {
    final expiryStr = await _storage.read(key: _tokenExpiryKey);
    if (expiryStr == null) return true;
    
    final expiresAt = DateTime.parse(expiryStr);
    return DateTime.now().isAfter(expiresAt);
  }
  
  /// Clear the stored refresh token
  /// 
  /// Should be called when:
  /// - User explicitly logs out
  /// - User disables biometric authentication
  /// - Token is invalidated by server
  Future<void> clearRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _tokenExpiryKey);
  }
  
  /// Check if biometric authentication is enabled
  Future<bool> isBiometricEnabled() async {
    final value = await _storage.read(key: _biometricEnabledKey);
    return value == 'true';
  }
  
  /// Enable or disable biometric authentication
  Future<void> setBiometricEnabled(bool enabled) async {
    if (enabled) {
      await _storage.write(key: _biometricEnabledKey, value: 'true');
    } else {
      await _storage.delete(key: _biometricEnabledKey);
      // Also clear tokens when disabling biometric
      await clearRefreshToken();
    }
  }
  
  /// Clear all stored authentication data
  Future<void> clearAll() async {
    await clearRefreshToken();
    await _storage.delete(key: _biometricEnabledKey);
  }
}

/// Data class representing a stored authentication token
class StoredToken {
  final String refreshToken;
  final String userId;
  final DateTime expiresAt;
  
  StoredToken({
    required this.refreshToken,
    required this.userId,
    required this.expiresAt,
  });
  
  /// Check if this token is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
