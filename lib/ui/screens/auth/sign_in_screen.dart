import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/auth/biometric_auth_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';
import 'dart:io' show Platform;

/// Modern sign in screen with multiple sign-in options:
/// - Continue with Biometric (if available)
/// - Continue with Google
/// - Continue with Login (email/password)
class SignInScreen extends ConsumerStatefulWidget {
  final bool autoPromptBiometric;

  const SignInScreen({
    super.key,
    this.autoPromptBiometric = false,
  });

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
    _checkBiometricAvailability();
    _maybeAutoPromptBiometric();
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
    final biometricAvailable = await _biometricService.isBiometricAvailable();
    
    if (mounted) {
      setState(() {
        // Always show biometric button if device supports it - never hide it
        _showBiometricOption = biometricAvailable;
      });
    }
  }

  void _maybeAutoPromptBiometric() {
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

      final hasStoredCredentials = await _biometricService.hasStoredCredentials();
      final hasStoredSession = await _biometricService.hasStoredSession();
      final hasActiveSession =
          Supabase.instance.client.auth.currentSession != null;
      if (!hasStoredCredentials && !hasStoredSession && !hasActiveSession) {
        return;
      }

      final currentState = WidgetsBinding.instance.lifecycleState;
      if (currentState != null &&
          currentState != AppLifecycleState.resumed) {
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
              content: Text(result.errorMessage ?? 'Biometric authentication failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Biometric successful - check if we have stored credentials
      final credentials = await _biometricService.getStoredCredentials();
      
      if (credentials != null) {
        // Email/password user - sign in with stored credentials
        final authService = ref.read(authServiceProvider);
        await authService.signInWithPassword(
          email: credentials['email']!,
          password: credentials['password']!,
        );
        _clearLocalLock();
        // Success! Auth gate will handle navigation
      } else {
        // OAuth user - if a valid session already exists, just unlock
        final currentSession = Supabase.instance.client.auth.currentSession;
        if (currentSession != null) {
          await _refreshBiometricSessionIfNeeded();
          _clearLocalLock();
          return;
        }

        // No active session - try to restore session from stored data
        final sessionString = await _biometricService.getStoredSession();
        if (sessionString != null) {
          try {
            // Debug: print what we're trying to recover
            print('Attempting to recover session from: ${sessionString.substring(0, 100)}...');
            
            await Supabase.instance.client.auth.recoverSession(sessionString);
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null) {
              // Session restored! Update stored session with fresh one
              final newSession = Supabase.instance.client.auth.currentSession;
              if (newSession != null) {
                await _biometricService.storeSession(jsonEncode(newSession.toJson()));
              }
              if (!await _refreshBiometricSessionIfNeeded()) {
                return;
              }
              _clearLocalLock();
              // Auth gate will handle navigation
              return;
            }
          } catch (e) {
            // Session invalid or expired - clear it and show detailed error
            print('Session recovery failed: $e');
            await _biometricService.clearStoredSession();
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
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
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
      if (refreshedSession != null) {
        await _biometricService.storeSession(jsonEncode(refreshedSession.toJson()));
      }
      return refreshedSession != null;
    } on AuthException catch (e) {
      await _biometricService.clearStoredSession();
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
          errorMessage = 'This Google account is already linked to another StatusXP account. Please sign in with that account first, or use a different sign-in method.';
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
          errorMessage = 'This Apple ID is already linked to your account. Please sign in with your email first, then you can use Apple Sign-In.';
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
            content: Text('Apple Sign-In failed: $e'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // App Logo/Icon
                Center(
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to icon if image fails to load
                      return Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: accentPrimary,
                          borderRadius: BorderRadius.circular(28),
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
                const SizedBox(height: 24),
                
                // App Name
                const Text(
                  'StatusXP',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Track your gaming achievements',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 60),
                
                // Continue with Biometric (only if available)
                if (_showBiometricOption) ...[
                  _buildOptionButton(
                    icon: Icons.fingerprint,
                    label: 'Continue with Biometric',
                    gradient: const LinearGradient(
                      colors: [accentPrimary, accentSecondary],
                    ),
                    onTap: _isLoading ? null : _signInWithBiometric,
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Continue with Google
                _buildOptionButton(
                  imagePath: 'assets/images/google_logo.png',
                  label: 'Continue with Google',
                  backgroundColor: Colors.white,
                  borderColor: Colors.grey.shade300,
                  textColor: Colors.black87,
                  onTap: _isLoading ? null : _signInWithGoogle,
                ),
                const SizedBox(height: 16),
                
                // Continue with Apple (iOS/macOS only)
                if (Platform.isIOS || Platform.isMacOS) ...[
                  _buildOptionButton(
                    icon: Icons.apple,
                    label: 'Continue with Apple',
                    backgroundColor: Colors.black,
                    textColor: Colors.white,
                    onTap: _isLoading ? null : _signInWithApple,
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Continue with Login (Email/Password)
                _buildOptionButton(
                  icon: Icons.email_outlined,
                  label: 'Continue with Login',
                  backgroundColor: Colors.black87,
                  textColor: Colors.white,
                  onTap: _isLoading ? null : _showEmailPasswordForm,
                ),
                
                // Loading indicator
                if (_isLoading) ...[
                  const SizedBox(height: 24),
                  const Center(
                    child: CircularProgressIndicator(),
                  ),
                ],
              ],
            ),
          ),
        ),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
        decoration: BoxDecoration(
          gradient: gradient,
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: borderColor != null
              ? Border.all(color: borderColor, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imagePath != null)
              Image.asset(
                imagePath,
                width: 28,
                height: 28,
              )
            else if (icon != null)
              Icon(
                icon,
                size: 28,
                color: textColor ?? Colors.white,
              ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: textColor ?? Colors.white,
              ),
            ),
          ],
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
      await authService.signInWithPassword(
        email: email,
        password: password,
      );
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
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
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
      await authService.signUp(
        email: email,
        password: password,
      );
      _clearLocalLock();
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
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
  
  const _EmailPasswordSheet({
    required this.onSignIn,
    required this.onSignUp,
  });

  @override
  State<_EmailPasswordSheet> createState() => _EmailPasswordSheetState();
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
                    borderSide: const BorderSide(color: accentPrimary, width: 2),
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
                    borderSide: const BorderSide(color: accentPrimary, width: 2),
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
                  if (_formKey.currentState!.validate()) {
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
                  style: const TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
