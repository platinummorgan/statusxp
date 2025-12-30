import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;

/// Service for managing Supabase authentication.
/// 
/// Provides a clean abstraction over Supabase Auth for email/password authentication,
/// Google Sign-In, session management, and auth state changes.
class AuthService {
  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;
  
  // Hardcoded Google Web Client ID (for backend/Supabase) - this is not sensitive and needs to be in the app
  // The Android client ID is auto-detected from package name + SHA-1
  static const String _googleClientId = '395832690159-snjk36er87mnvh21bkk10f6lu6i9abaq.apps.googleusercontent.com';
  
  AuthService(this._client) 
      : _googleSignIn = GoogleSignIn(
          serverClientId: _googleClientId,
        );
  
  /// Sign up a new user with email and password.
  /// 
  /// Returns an [AuthResponse] containing the user and session if successful.
  /// Throws [AuthException] if sign up fails (e.g., email already exists, weak password).
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: 'com.platovalabs.statusxp://login-callback',
    );
  }
  
  /// Sign in an existing user with email and password.
  /// 
  /// Returns an [AuthResponse] containing the user and session if successful.
  /// Throws [AuthException] if credentials are invalid.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  /// Send a password reset email to the user.
  /// 
  /// The user will receive an email with a link to reset their password.
  /// The link will redirect to the app using the deep link configured in Supabase.
  /// Throws [AuthException] if the email sending fails.
  Future<void> resetPassword({
    required String email,
  }) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: 'com.platovalabs.statusxp://reset-password',
    );
  }
  
  /// Update the user's password.
  /// 
  /// This should be called after the user follows the password reset link.
  /// Throws [AuthException] if the password update fails.
  Future<UserResponse> updatePassword({
    required String newPassword,
  }) async {
    return await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
  
  /// Delete the current user's account and all associated data.
  /// 
  /// This will permanently delete:
  /// - User authentication account
  /// - Profile and all gaming data
  /// - Game achievements and trophies
  /// - Premium subscriptions and purchases
  /// - AI credits and usage history
  /// 
  /// This action cannot be undone.
  /// Throws [AuthException] if deletion fails.
  Future<void> deleteAccount() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('No user logged in');
    }
    
    // Call edge function to delete all user data from database
    final response = await _client.functions.invoke('delete-account');
    
    if (response.status != 200) {
      throw AuthException(response.data?['error'] ?? 'Failed to delete account data');
    }
    
    // Sign out after deletion
    await _client.auth.signOut();
  }
  
  /// Sign out the current user.
  /// 
  /// Clears the session and revokes the refresh token.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
  
  /// Sign in with Google using OAuth.
  /// 
  /// Opens Google Sign-In flow and exchanges the Google ID token for a Supabase session.
  /// Throws [AuthException] if sign in fails or is cancelled.
  Future<AuthResponse> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw const AuthException('Google Sign-In was cancelled');
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;
      
      if (idToken == null) {
        throw const AuthException('Failed to get Google ID token');
      }
      
      // Sign in to Supabase with Google credentials
      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  /// Sign in with Apple using OAuth.
  /// 
  /// Opens Apple Sign-In flow and exchanges the Apple ID token for a Supabase session.
  /// Throws [AuthException] if sign in fails or is cancelled.
  /// Only available on iOS 13+ and macOS 10.15+.
  Future<AuthResponse> signInWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      
      final idToken = credential.identityToken;
      
      if (idToken == null) {
        throw const AuthException('Failed to get Apple ID token');
      }
      
      // Sign in to Supabase with Apple credentials
      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  /// Check if Sign in with Apple is available on this platform.
  /// 
  /// Returns true on iOS 13+ and macOS 10.15+, false otherwise.
  Future<bool> get isAppleSignInAvailable async {
    try {
      return Platform.isIOS || Platform.isMacOS;
    } catch (e) {
      return false;
    }
  }
  
  /// Get the currently authenticated user.
  /// 
  /// Returns the [User] if there is an active session, null otherwise.
  User? get currentUser => _client.auth.currentUser;
  
  /// Stream of authentication state changes.
  /// 
  /// Emits an [AuthState] whenever the user signs in, signs out, or the token refreshes.
  /// Use this to reactively update UI based on authentication status.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
}
