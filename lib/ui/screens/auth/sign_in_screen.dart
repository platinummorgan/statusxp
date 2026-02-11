import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/auth/biometric_auth_service.dart';
import 'package:statusxp/data/auth/auth_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';

/// Modern sign in screen with multiple sign-in options:
/// - Continue with Biometric (if available)
/// - Continue with Google
/// - Continue with Login (email/password)
class SignInScreen extends ConsumerStatefulWidget {
  final bool autoPromptBiometric;

  const SignInScreen({super.key, this.autoPromptBiometric = false});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen>
    with WidgetsBindingObserver {
  final BiometricAuthService _biometricService = BiometricAuthService();

  bool _isLoading = false;
  bool _showBiometricOption = false;
  bool _hasAutoPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) {
      _checkBiometricAvailability();
      _maybeAutoPromptBiometric();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeAutoPromptBiometric();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _hasAutoPrompted = false;
    }
  }

  /// Check if biometric sign-in is available
  Future<void> _checkBiometricAvailability() async {
    if (kIsWeb) return;
    final biometricAvailable = await _biometricService.isBiometricAvailable();

    if (mounted) {
      setState(() {
        // Always show biometric button if device supports it - never hide it
        _showBiometricOption = biometricAvailable;
      });
    }
  }

  void _maybeAutoPromptBiometric() {
    if (kIsWeb) return;
    if (!widget.autoPromptBiometric || _hasAutoPrompted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _hasAutoPrompted || _isLoading) return;
      final lifecycleState = WidgetsBinding.instance.lifecycleState;
      if (lifecycleState != null &&
          lifecycleState != AppLifecycleState.resumed) {
        return;
      }

      final isEnabled = await _biometricService.isBiometricEnabled();
      if (!isEnabled) return;

      final hasStoredCredentials = await _biometricService
          .hasStoredCredentials();
      final hasStoredToken = await _biometricService.hasStoredRefreshToken();
      final hasActiveSession =
          Supabase.instance.client.auth.currentSession != null;
      if (!hasStoredCredentials && !hasStoredToken && !hasActiveSession) {
        return;
      }

      final currentState = WidgetsBinding.instance.lifecycleState;
      if (currentState != null && currentState != AppLifecycleState.resumed) {
        _hasAutoPrompted = false;
        return;
      }

      _hasAutoPrompted = true;
      await _signInWithBiometric();
    });
  }

  /// Sign in with biometric authentication
  Future<void> _signInWithBiometric() async {
    setState(() => _isLoading = true);

    try {
      // Check if biometric is actually enabled
      final isEnabled = await _biometricService.isBiometricEnabled();

      if (!isEnabled) {
        // Biometric not set up yet
        if (mounted) {
          setState(() => _isLoading = false);
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Biometric Not Set Up'),
              content: const Text(
                'Please sign in first using Google, Apple, or Email/Password.\n\n'
                'Then go to Settings and enable biometric authentication.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Authenticate with biometric
      final result = await _biometricService.authenticate(
        reason: 'Sign in to StatusXP',
      );

      if (!result.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.errorMessage ?? 'Biometric authentication failed',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Biometric successful - check if we have stored credentials
      final credentials = await _biometricService.getStoredCredentials();

      if (credentials != null) {
        final email = credentials['email'];
        final password = credentials['password'];

        if (email != null && password != null) {
          // Email/password user - sign in with stored credentials
          final authService = ref.read(authServiceProvider);
          await authService.signInWithPassword(
            email: email,
            password: password,
          );
          _clearLocalLock();
          // Success! Auth gate will handle navigation
        } else {
          // Invalid credentials stored - clear and show error
          await _biometricService.clearStoredCredentials();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Invalid credentials stored. Please sign in again.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } else {
        // OAuth user - if a valid session already exists, just unlock
        final currentSession = Supabase.instance.client.auth.currentSession;
        if (currentSession != null) {
          await _refreshBiometricSessionIfNeeded();
          _clearLocalLock();
          return;
        }

        // No active session - try to restore session from stored refresh token
        final storedToken = await _biometricService.getRefreshToken();
        if (storedToken != null && !storedToken.isExpired) {
          try {
            final authService = AuthService(Supabase.instance.client);
            final restored = await authService.restoreSessionFromRefreshToken(
              storedToken.refreshToken,
            );
            if (restored) {
              // Update stored token with new one from refreshed session
              final newToken = authService.refreshToken;
              final newExpiry = authService.refreshTokenExpiry;
              if (newToken != null &&
                  newExpiry != null &&
                  authService.currentUser != null) {
                await _biometricService.storeRefreshToken(
                  refreshToken: newToken,
                  userId: authService.currentUser!.id,
                  expiresAt: newExpiry,
                );
              }
              _clearLocalLock();
              // Auth gate will handle navigation
              return;
            } else {
              print('🔐 Token invalid - session could not be restored');
            }
          } catch (e) {
            // Token invalid or expired - clear it and show detailed error
            print('Token refresh failed: $e');
            await _biometricService.clearRefreshToken();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Session expired: ${e.toString()}'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return;
          }
        }

        // No stored refresh token and no active session
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please sign in with Google or Apple'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _clearLocalLock() {
    ref.read(biometricLockRequestedProvider.notifier).state = false;
    ref.read(biometricUnlockGrantedProvider.notifier).state = true;
  }

  Future<bool> _refreshBiometricSessionIfNeeded() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return false;
    }

    final expiresAt = session.expiresAt;
    if (expiresAt == null) {
      return true;
    }

    final expiry = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
    final shouldRefresh = expiry.isBefore(
      DateTime.now().add(const Duration(minutes: 2)),
    );
    if (!shouldRefresh) {
      return true;
    }

    try {
      final refreshed = await Supabase.instance.client.auth.refreshSession();
      final refreshedSession =
          refreshed.session ?? Supabase.instance.client.auth.currentSession;
      if (refreshedSession != null &&
          refreshedSession.refreshToken != null &&
          refreshedSession.expiresAt != null) {
        // Store the new refresh token
        final expiresAt = DateTime.fromMillisecondsSinceEpoch(
          refreshedSession.expiresAt! * 1000,
        );
        await _biometricService.storeRefreshToken(
          refreshToken: refreshedSession.refreshToken!,
          userId: refreshedSession.user.id,
          expiresAt: expiresAt,
        );
      }
      return refreshedSession != null;
    } on AuthException catch (e) {
      await _biometricService.clearRefreshToken();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Session expired. Please sign in again to continue. ($e)',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }
  }

  /// Sign in with Google
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    try {
      final currentUser = authService.currentUser;

      await authService.signInWithGoogle();
      _clearLocalLock();

      // Mark that user has signed in at least once
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_signed_in_before', true);

      // Show success message if we linked an account
      if (currentUser != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Google account linked successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      // AuthGate will handle navigation automatically
    } on AuthException catch (e) {
      if (mounted) {
        // Show user-friendly error message
        String errorMessage = e.message;
        if (e.message.contains('already linked')) {
          errorMessage =
              'This Google account is already linked to another StatusXP account. Please sign in with that account first, or use a different sign-in method.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Sign in with Apple
  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    try {
      final currentUser = authService.currentUser;

      await authService.signInWithApple();
      _clearLocalLock();

      // Mark that user has signed in at least once
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_signed_in_before', true);

      // Show success message if we linked an account
      if (currentUser != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Apple account linked successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
      // AuthGate will handle navigation automatically
    } on AuthException catch (e) {
      if (mounted) {
        // Show user-friendly error message
        String errorMessage = e.message;
        if (e.message.contains('already linked')) {
          errorMessage =
              'This Apple ID is already linked to your account. Please sign in with your email first, then you can use Apple Sign-In.';
        } else if (e.message.contains('PlatformException') ||
            e.message.contains('Error while launching')) {
          errorMessage =
              'Apple Sign-In configuration error. Please try signing in with email or Google instead.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Apple Sign-In failed: $e';
        if (e.toString().contains('PlatformException') ||
            e.toString().contains('Error while launching')) {
          errorMessage =
              'Apple Sign-In is not properly configured on this device. Please use email or Google sign-in instead.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Show forgot password dialog
  void _showForgotPasswordDialog(BuildContext parentContext) {
    final resetEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context);
                // Show loading indicator
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Sending reset link...'),
                    duration: Duration(seconds: 2),
                  ),
                );

                try {
                  // Send password reset email with platform-specific redirect
                  const redirectUrl = kIsWeb
                      ? 'https://statusxp.com/reset-password'
                      : 'com.statusxp.statusxp://reset-password';
                  await Supabase.instance.client.auth.resetPasswordForEmail(
                    resetEmailController.text.trim(),
                    redirectTo: redirectUrl,
                  );

                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '✅ Password reset link sent! Check your email.',
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send reset link: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isPhone = media.size.width < 600;
    final isCompact = media.size.height < 760 || media.size.width < 380;
    final useFramedCard = !isPhone;
    final logoSize = isCompact ? 74.0 : 96.0;
    final horizontalPadding = isPhone ? 10.0 : (isCompact ? 16.0 : 20.0);
    final cardPadding = isCompact
        ? const EdgeInsets.fromLTRB(12, 12, 12, 10)
        : const EdgeInsets.fromLTRB(16, 16, 16, 12);
    final cardMaxWidth = isPhone ? 430.0 : (isCompact ? 340.0 : 390.0);
    final buttonMaxWidth = isPhone
        ? double.infinity
        : (isCompact ? 258.0 : 300.0);

    return Scaffold(
      backgroundColor: backgroundDark,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    backgroundDark,
                    surfaceDark.withOpacity(0.95),
                    backgroundDark,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -100,
            right: -64,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentPrimary.withOpacity(0.16),
              ),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -58,
            child: Container(
              width: 230,
              height: 230,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentSecondary.withOpacity(0.12),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: isPhone ? Alignment.topCenter : Alignment.center,
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isPhone ? 8 : (isCompact ? 16 : 24),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: cardMaxWidth),
                  child: Container(
                    decoration: BoxDecoration(
                      color: surfaceDark.withOpacity(
                        useFramedCard ? 0.92 : 0.76,
                      ),
                      borderRadius: BorderRadius.circular(
                        useFramedCard ? 18 : 14,
                      ),
                      border: useFramedCard
                          ? Border.all(color: accentPrimary.withOpacity(0.24))
                          : null,
                      boxShadow: useFramedCard
                          ? [
                              BoxShadow(
                                color: accentSecondary.withOpacity(0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: Colors.black.withOpacity(0.26),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ]
                          : null,
                    ),
                    padding: cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: accentPrimary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: accentPrimary.withOpacity(0.35),
                              ),
                            ),
                            child: const Text(
                              'NEURAL ACCESS',
                              style: TextStyle(
                                fontSize: 10.5,
                                letterSpacing: 1.1,
                                fontWeight: FontWeight.w700,
                                color: accentPrimary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: isCompact ? 8 : 12),

                        // Keep existing app logo as requested.
                        Center(
                          child: Container(
                            width: logoSize,
                            height: logoSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: accentPrimary.withOpacity(0.25),
                                  blurRadius: 26,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/app_icon.png',
                              width: 124,
                              height: 124,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 124,
                                  height: 124,
                                  decoration: BoxDecoration(
                                    color: accentPrimary,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: const Icon(
                                    Icons.videogame_asset,
                                    size: 64,
                                    color: Colors.white,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: isCompact ? 8 : 12),

                        Text(
                          'StatusXP',
                          style: TextStyle(
                            fontSize: isCompact ? 22 : 27,
                            fontWeight: FontWeight.w800,
                            color: textPrimary,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sync trophies. Build rank. Dominate leaderboards.',
                          style: TextStyle(
                            fontSize: isCompact ? 11.6 : 12.6,
                            height: 1.4,
                            color: textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        if (!isCompact && media.size.height > 760) ...[
                          const Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _AuthFeaturePill(
                                icon: Icons.sync,
                                label: 'Fast Sync',
                              ),
                              _AuthFeaturePill(
                                icon: Icons.emoji_events_outlined,
                                label: 'Leaderboards',
                              ),
                              _AuthFeaturePill(
                                icon: Icons.public,
                                label: 'Cross-Platform',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ] else
                          const SizedBox(height: 6),

                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.14),
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                'CHOOSE SIGN IN METHOD',
                                style: TextStyle(
                                  color: textMuted.withOpacity(0.85),
                                  fontSize: isCompact ? 10 : 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.9,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.white.withOpacity(0.14),
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        if (_showBiometricOption) ...[
                          Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: buttonMaxWidth,
                              ),
                              child: _buildOptionButton(
                                icon: Icons.fingerprint,
                                label: 'Biometric',
                                gradient: const LinearGradient(
                                  colors: [accentPrimary, accentSecondary],
                                ),
                                borderColor: accentPrimary.withOpacity(0.8),
                                onTap: _isLoading ? null : _signInWithBiometric,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],

                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: buttonMaxWidth,
                            ),
                            child: _buildOptionButton(
                              imagePath: 'assets/images/google_logo.png',
                              label: 'Google',
                              backgroundColor: Colors.white,
                              borderColor: Colors.white.withOpacity(0.85),
                              textColor: Colors.black87,
                              onTap: _isLoading ? null : _signInWithGoogle,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: buttonMaxWidth,
                            ),
                            child: _buildOptionButton(
                              icon: Icons.apple,
                              label: 'Apple',
                              backgroundColor: Colors.black,
                              borderColor: accentSecondary.withOpacity(0.75),
                              textColor: Colors.white,
                              onTap: _isLoading ? null : _signInWithApple,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),

                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: buttonMaxWidth,
                            ),
                            child: _buildOptionButton(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              backgroundColor: surfaceLight,
                              borderColor: accentPrimary.withOpacity(0.55),
                              textColor: textPrimary,
                              onTap: _isLoading ? null : _showEmailPasswordForm,
                            ),
                          ),
                        ),

                        const SizedBox(height: 2),
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => _showForgotPasswordDialog(context),
                          child: const Text(
                            'Forgot your password?',
                            style: TextStyle(
                              color: accentPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        if (!isCompact) ...[
                          const SizedBox(height: 6),
                          Text(
                            'New to StatusXP? Use Email to create your account.',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondary.withOpacity(0.8),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],

                        if (_isLoading) ...[
                          const SizedBox(height: 8),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionButton({
    IconData? icon,
    String? imagePath,
    required String label,
    Gradient? gradient,
    Color? backgroundColor,
    Color? borderColor,
    Color? textColor,
    VoidCallback? onTap,
  }) {
    final effectiveTextColor = textColor ?? Colors.white;
    final isDisabled = onTap == null;
    final isLightButton = backgroundColor == Colors.white;
    final baseColor = backgroundColor ?? surfaceLight;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Opacity(
        opacity: isDisabled ? 0.65 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 9),
          decoration: BoxDecoration(
            gradient: gradient,
            color: gradient == null ? baseColor : null,
            borderRadius: BorderRadius.circular(9),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1.1)
                : Border.all(
                    color: isLightButton
                        ? Colors.white.withOpacity(0.65)
                        : accentPrimary.withOpacity(0.35),
                    width: 1,
                  ),
            boxShadow: [
              BoxShadow(
                color: isLightButton
                    ? Colors.black.withOpacity(0.12)
                    : accentPrimary.withOpacity(0.09),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isLightButton
                        ? Colors.black.withOpacity(0.08)
                        : accentSecondary.withOpacity(0.25),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isLightButton
                          ? Colors.black.withOpacity(0.08)
                          : Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isLightButton
                            ? Colors.black.withOpacity(0.15)
                            : accentPrimary.withOpacity(0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Center(
                      child: imagePath != null
                          ? Image.asset(imagePath, width: 14, height: 14)
                          : icon != null
                          ? Icon(icon, size: 14, color: effectiveTextColor)
                          : const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: effectiveTextColor,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show email/password dialog
  void _showEmailPasswordForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EmailPasswordSheet(
        onSignIn: (email, password) async {
          Navigator.pop(context);
          await _signInWithPassword(email, password);
        },
        onSignUp: (email, password) async {
          Navigator.pop(context);
          await _signUpWithPassword(email, password);
        },
      ),
    );
  }

  Future<void> _signInWithPassword(String email, String password) async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithPassword(email: email, password: password);
      _clearLocalLock();

      // Mark that user has signed in at least once
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_signed_in_before', true);

      // Store credentials for biometric auth (if enabled)
      final biometricEnabled = await _biometricService.isBiometricEnabled();
      if (biometricEnabled) {
        await _biometricService.storeCredentials(email, password);
      }

      // Refresh biometric button visibility
      if (mounted) {
        await _checkBiometricAvailability();
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );

        // Store credentials for biometric auth (if enabled)
        final biometricEnabled = await _biometricService.isBiometricEnabled();
        if (biometricEnabled) {
          await _biometricService.storeCredentials(email, password);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUpWithPassword(String email, String password) async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signUp(email: email, password: password);
      _clearLocalLock();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign up failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// Bottom sheet for email/password entry
class _EmailPasswordSheet extends StatefulWidget {
  final Function(String email, String password) onSignIn;
  final Function(String email, String password) onSignUp;

  const _EmailPasswordSheet({required this.onSignIn, required this.onSignUp});

  @override
  State<_EmailPasswordSheet> createState() => _EmailPasswordSheetState();
}

class _AuthFeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _AuthFeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accentPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailPasswordSheetState extends State<_EmailPasswordSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoginMode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showForgotPasswordDialog(BuildContext parentContext) {
    final resetEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your email address and we\'ll send you a link to reset your password.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context);
                // Show loading indicator
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text('Sending reset link...'),
                    duration: Duration(seconds: 2),
                  ),
                );

                try {
                  // Send password reset email with platform-specific redirect
                  const redirectUrl = kIsWeb
                      ? 'https://statusxp.com/reset-password'
                      : 'com.statusxp.statusxp://reset-password';
                  await Supabase.instance.client.auth.resetPasswordForEmail(
                    resetEmailController.text.trim(),
                    redirectTo: redirectUrl,
                  );

                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          '✅ Password reset link sent! Check your email.',
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  if (parentContext.mounted) {
                    ScaffoldMessenger.of(parentContext).showSnackBar(
                      SnackBar(
                        content: Text('Failed to send reset link: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                _isLoginMode ? 'Sign In' : 'Create Account',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Email Field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: Colors.black54),
                  hintText: 'Enter your email',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: accentPrimary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.black87),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: Colors.black54),
                  hintText: 'Enter your password',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: accentPrimary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState?.validate() ?? false) {
                    if (_isLoginMode) {
                      widget.onSignIn(
                        _emailController.text.trim(),
                        _passwordController.text,
                      );
                    } else {
                      widget.onSignUp(
                        _emailController.text.trim(),
                        _passwordController.text,
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isLoginMode ? 'Sign In' : 'Create Account',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Forgot Password (only show in login mode)
              if (_isLoginMode)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // Show forgot password dialog
                      Navigator.pop(context); // Close current sheet
                      _showForgotPasswordDialog(context);
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color: accentPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

              // Toggle between sign in / sign up
              TextButton(
                onPressed: () {
                  setState(() {
                    _isLoginMode = !_isLoginMode;
                  });
                },
                child: Text(
                  _isLoginMode
                      ? "Don't have an account? Sign Up"
                      : 'Already have an account? Sign In',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
