import 'package:flutter/material.dart';
import 'package:statusxp/data/auth/biometric_auth_service.dart';
import 'package:statusxp/theme/colors.dart';

/// Screen that appears when biometric authentication is required to unlock the app
class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;
  
  const BiometricLockScreen({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final BiometricAuthService _biometricService = BiometricAuthService();
  bool _isAuthenticating = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    // Automatically prompt for biometrics when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authenticateWithBiometrics();
    });
  }

  Future<void> _authenticateWithBiometrics() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    try {
      final authenticated = await _biometricService.authenticate(
        reason: 'Unlock StatusXP',
      );

      if (authenticated) {
        widget.onAuthenticated();
      } else {
        setState(() {
          _errorMessage = 'Authentication failed. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Biometric authentication error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundDark,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App icon/logo
                const Icon(
                  Icons.shield_outlined,
                  size: 120,
                  color: accentPrimary,
                ),
                const SizedBox(height: 32),
                
                // Title
                const Text(
                  'StatusXP is Locked',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Description
                const Text(
                  'Use your fingerprint or face to unlock',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Biometric icon button
                if (!_isAuthenticating)
                  InkWell(
                    onTap: _authenticateWithBiometrics,
                    borderRadius: BorderRadius.circular(60),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accentPrimary,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.fingerprint,
                        size: 64,
                        color: accentPrimary,
                      ),
                    ),
                  ),
                
                // Loading indicator
                if (_isAuthenticating)
                  const CircularProgressIndicator(
                    color: accentPrimary,
                  ),
                
                const SizedBox(height: 24),
                
                // Error message
                if (_errorMessage.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Retry button (only show after error)
                if (_errorMessage.isNotEmpty && !_isAuthenticating)
                  TextButton.icon(
                    onPressed: _authenticateWithBiometrics,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: TextButton.styleFrom(
                      foregroundColor: accentPrimary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
