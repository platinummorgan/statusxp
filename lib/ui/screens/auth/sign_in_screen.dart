import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/auth/biometric_auth_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';

/// Modern sign in screen with 3 prominent options:
/// - Continue with Biometric (if available)
/// - Continue with Google
/// - Continue with Login (email/password)
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final BiometricAuthService _biometricService = BiometricAuthService();
  
  bool _isLoading = false;
  bool _showBiometricOption = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  /// Check if biometric sign-in is available
  Future<void> _checkBiometricAvailability() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSignedInBefore = prefs.getBool('has_signed_in_before') ?? false;
    final biometricEnabled = await _biometricService.isBiometricEnabled();
    final biometricAvailable = await _biometricService.isBiometricAvailable();
    
    // Check if we have stored credentials
    final hasStoredCredentials = await _biometricService.hasStoredCredentials();
    
    if (mounted) {
      setState(() {
        // Show biometric option if:
        // 1. User has signed in before
        // 2. Biometric is enabled in settings
        // 3. Device supports biometric
        // 4. We have stored credentials to use
        _showBiometricOption = hasSignedInBefore && 
                                biometricEnabled && 
                                biometricAvailable && 
                                hasStoredCredentials;
      });
    }
  }

  /// Sign in with biometric authentication
  Future<void> _signInWithBiometric() async {
    setState(() => _isLoading = true);
    
    try {
      // Authenticate with biometric first
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
      
      // Biometric successful - retrieve stored credentials
      final credentials = await _biometricService.getStoredCredentials();
      
      if (credentials == null) {
        // No stored credentials - shouldn't happen but handle it
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No stored credentials found. Please sign in with email or Google.'),
              backgroundColor: Colors.orange,
            ),
          );
          await _checkBiometricAvailability(); // Refresh button visibility
        }
        return;
      }
      
      // Sign in with stored credentials
      final authService = ref.read(authServiceProvider);
      await authService.signInWithPassword(
        email: credentials['email']!,
        password: credentials['password']!,
      );
      
      // Success! Auth gate will handle navigation
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

  /// Sign in with Google
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    try {
      final currentUser = authService.currentUser;
      
      await authService.signInWithGoogle();
      
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
                  icon: Icons.g_mobiledata,
                  label: 'Continue with Google',
                  backgroundColor: Colors.white,
                  borderColor: Colors.grey.shade300,
                  textColor: Colors.black87,
                  onTap: _isLoading ? null : _signInWithGoogle,
                ),
                const SizedBox(height: 16),
                
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
    required IconData icon,
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
