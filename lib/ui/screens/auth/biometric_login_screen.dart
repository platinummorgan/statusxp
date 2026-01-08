import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/data/auth/biometric_auth_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Screen that shows a biometric authentication prompt
/// 
/// This screen is shown when:
/// - App starts and user has biometric auth enabled
/// - User returns to app after backgrounding with biometric lock enabled
/// 
/// Flow:
/// 1. Show biometric prompt immediately
/// 2. On success, retrieve refresh token from secure storage
/// 3. Exchange refresh token for new access token
/// 4. Navigate to home screen
/// 5. On failure/cancel, show sign-in options
class BiometricLoginScreen extends ConsumerStatefulWidget {
  const BiometricLoginScreen({super.key});

  @override
  ConsumerState<BiometricLoginScreen> createState() => _BiometricLoginScreenState();
}

class _BiometricLoginScreenState extends ConsumerState<BiometricLoginScreen> {
  bool _isAuthenticating = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    // Start biometric authentication immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticateWithBiometrics();
    });
  }
  
  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });
    
    try {
      final biometricService = BiometricAuthService();
      final authService = ref.read(authServiceProvider);
      
      // Step 1: Perform biometric authentication
      final authResult = await biometricService.authenticate(
        reason: 'Unlock StatusXP with your biometrics',
      );
      
      if (!authResult.success) {
        setState(() {
          _errorMessage = authResult.errorMessage ?? 'Authentication failed';
          _isAuthenticating = false;
        });
        return;
      }
      
      // Step 2: Retrieve stored refresh token
      final storedToken = await biometricService.getRefreshToken();
      
      if (storedToken == null) {
        setState(() {
          _errorMessage = 'No stored credentials found. Please sign in again.';
          _isAuthenticating = false;
        });
        await biometricService.clearRefreshToken();
        return;
      }
      
      // Check if token is expired
      if (storedToken.isExpired) {
        setState(() {
          _errorMessage = 'Session expired. Please sign in again.';
          _isAuthenticating = false;
        });
        await biometricService.clearRefreshToken();
        return;
      }
      
      // Step 3: Exchange refresh token for new session
      final success = await authService.restoreSessionFromRefreshToken(
        storedToken.refreshToken,
      );
      
      if (!success) {
        setState(() {
          _errorMessage = 'Session could not be restored. Please sign in again.';
          _isAuthenticating = false;
        });
        await biometricService.clearRefreshToken();
        return;
      }
      
      // Step 4: Update stored refresh token with new one from refreshed session
      final newRefreshToken = authService.refreshToken;
      final newExpiry = authService.refreshTokenExpiry;
      
      if (newRefreshToken != null && newExpiry != null) {
        await biometricService.storeRefreshToken(
          refreshToken: newRefreshToken,
          userId: authService.currentUser!.id,
          expiresAt: newExpiry,
        );
      }
      
      // Success! User is now authenticated
      // AuthGate will automatically navigate to home screen via authStateProvider
      
    } on AuthException catch (e) {
      final biometricService = BiometricAuthService();
      setState(() {
        _errorMessage = 'Authentication failed: ${e.message}';
        _isAuthenticating = false;
      });
      await biometricService.clearRefreshToken();
    } catch (e) {
      final biometricService = BiometricAuthService();
      // Handle network errors gracefully
      final errorStr = e.toString();
      if (errorStr.contains('SocketException') || 
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('ClientException')) {
        setState(() {
          _errorMessage = 'Network connection error. Please check your internet connection and try again.';
          _isAuthenticating = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Authentication error: ${e.toString()}';
          _isAuthenticating = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo or Icon
              const Icon(
                Icons.fingerprint,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              
              // Title
              Text(
                'Welcome Back!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Instructions
              if (_isAuthenticating && _errorMessage == null)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Authenticating...',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              
              // Error message
              if (_errorMessage != null)
                Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Retry button
                    ElevatedButton.icon(
                      onPressed: _authenticateWithBiometrics,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Try Again'),
                    ),
                    const SizedBox(height: 16),
                    
                    // Sign in with password button
                    TextButton(
                      onPressed: () {
                        // Navigate to sign-in screen
                        // The AuthGate will handle this by showing sign-in options
                        ref.read(biometricAuthServiceProvider).clearRefreshToken();
                      },
                      child: const Text('Sign in with password'),
                    ),
                  ],
                ),
              
              const SizedBox(height: 48),
              
              // Security note
              Text(
                'Your credentials are securely stored in your device\'s encrypted keychain',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
