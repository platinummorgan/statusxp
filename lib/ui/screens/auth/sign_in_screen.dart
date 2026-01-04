import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:statusxp/data/auth/biometric_auth_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/ui/screens/auth/forgot_password_screen.dart';
import 'dart:io' show Platform;

/// Sign in and sign up screen for Supabase email/password authentication.
/// 
/// Supports toggling between login and registration modes.
/// Uses StatusXP theme with neon accents and dark background.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final BiometricAuthService _biometricService = BiometricAuthService();
  
  bool _isLoginMode = true;
  bool _isLoading = false;
  bool _showBiometricOption = false;
  
  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  /// Check if biometric sign-in is available
  Future<void> _checkBiometricAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSignedInBefore = prefs.getBool('has_signed_in_before') ?? false;
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    final biometricAvailable = await _biometricService.isBiometricAvailable();
    
    if (mounted) {
      setState(() {
        _showBiometricOption = hasSignedInBefore && biometricEnabled && biometricAvailable;
      });
    }
  }
  
  /// Sign in with biometric authentication
  Future<void> _signInWithBiometric() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _biometricService.authenticate(
        reason: 'Sign in to StatusXP',
      );
      
      if (result.success) {
        // Biometric authentication successful - session should still be valid
        final currentUser = Supabase.instance.client.auth.currentUser;
        
        if (currentUser == null) {
          // Session expired
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Session expired. Please sign in with your email and password.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        // If user exists, auth gate will handle navigation automatically
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.errorMessage ?? 'Biometric authentication failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
  
  /// Validate email format.
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    if (!value.contains('@')) {
      return 'Please enter a valid email';
    }
    return null;
  }
  
  /// Validate password length.
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }
  
  /// Handle sign in or sign up.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      
      if (_isLoginMode) {
        await authService.signInWithPassword(
          email: email,
          password: password,
        );
        
        // Mark that user has signed in at least once
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_signed_in_before', true);
      } else {
        await authService.signUp(
          email: email,
          password: password,
        );
      }
      
      // AuthGate will handle navigation automatically via auth state stream
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
            content: Text('An error occurred: $e'),
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
      backgroundColor: backgroundDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Title
                  Text(
                    'StatusXP',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: accentPrimary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoginMode ? 'Welcome Back' : 'Create Account',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: textSecondary,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),
                  
                  // Biometric Sign In Button (only show if available)
                  if (_showBiometricOption && _isLoginMode) ...[
                    InkWell(
                      onTap: _isLoading ? null : _signInWithBiometric,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              accentPrimary.withOpacity(0.1),
                              accentSecondary.withOpacity(0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentPrimary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.fingerprint,
                              size: 64,
                              color: accentPrimary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sign in with Biometric',
                              style: TextStyle(
                                color: accentPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FutureBuilder<String>(
                              future: _biometricService.getBiometricTypesDescription(),
                              builder: (context, snapshot) {
                                return Text(
                                  'Use ${snapshot.data ?? "biometric"} to sign in',
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 14,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: Divider(color: textSecondary.withOpacity(0.3))),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: textSecondary.withOpacity(0.3))),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: const TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: const TextStyle(color: textSecondary),
                      prefixIcon: const Icon(Icons.email, color: accentPrimary),
                      filled: true,
                      fillColor: surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: accentPrimary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: _validateEmail,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    style: const TextStyle(color: textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: const TextStyle(color: textSecondary),
                      prefixIcon: const Icon(Icons.lock, color: accentPrimary),
                      filled: true,
                      fillColor: surfaceDark,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: accentPrimary, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.red, width: 2),
                      ),
                    ),
                    validator: _validatePassword,
                    enabled: !_isLoading,
                  ),
                  
                  // Forgot Password Link (only show in login mode)
                  if (_isLoginMode) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading ? null : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(color: accentPrimary),
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentPrimary,
                      foregroundColor: backgroundDark,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(backgroundDark),
                            ),
                          )
                        : Text(
                            _isLoginMode ? 'Sign In' : 'Create Account',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Divider with "OR"
                  const Row(
                    children: [
                      Expanded(child: Divider(color: textSecondary)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(color: textSecondary),
                        ),
                      ),
                      Expanded(child: Divider(color: textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Apple Sign-In Button (iOS/macOS only, required by Apple)
                  if (Platform.isIOS || Platform.isMacOS)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SignInWithAppleButton(
                        onPressed: _isLoading ? () {} : _signInWithApple,
                        text: 'Sign in with Apple',
                        height: 48,
                        style: SignInWithAppleButtonStyle.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  
                  // Google Sign-In Button (Official Google branding)
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1F1F1F),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: const BorderSide(color: Color(0xFF747775), width: 1),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/google_logo.png',
                            height: 20,
                            width: 20,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Sign in with Google',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Roboto',
                              letterSpacing: 0.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Toggle Mode Button
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isLoginMode = !_isLoginMode;
                              _formKey.currentState?.reset();
                            });
                          },
                    child: Text(
                      _isLoginMode
                          ? 'Need an account? Create one'
                          : 'Already have an account? Sign in',
                      style: const TextStyle(
                        color: accentSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  /// Handle Google Sign-In
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    try {
      final currentUser = authService.currentUser;
      
      await authService.signInWithGoogle();
      
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
  
  /// Handle Apple Sign-In
  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    
    try {
      final authService = ref.read(authServiceProvider);
      final currentUser = authService.currentUser;
      
      await authService.signInWithApple();
      
      // Show success message if we linked an account
      if (currentUser != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Apple ID linked successfully!'),
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
          errorMessage = 'This Apple ID is already linked to another StatusXP account. Please sign in with that account first, or use a different sign-in method.';
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
}
