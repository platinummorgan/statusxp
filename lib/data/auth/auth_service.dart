import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service for managing Supabase authentication.
/// 
/// Provides a clean abstraction over Supabase Auth for email/password authentication,
/// Google Sign-In, session management, and auth state changes.
class AuthService {
  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;
  
  // Hardcoded Google Web Client ID (for backend/Supabase) - this is not sensitive and needs to be in the app
  // On Android: Use serverClientId for OAuth flow
  // On iOS: Use clientId with the iOS OAuth client ID
  static const String _googleClientId = '395832690159-snjk36er87mnvh21bkk10f6lu6i9abaq.apps.googleusercontent.com';
  static const String _googleiOSClientId = '395832690159-psp0hu5uggjc7u2lmfhnmim016j2lhq2.apps.googleusercontent.com';
  
  AuthService(this._client) 
      : _googleSignIn = GoogleSignIn(
          // On Android: use serverClientId for backend OAuth
          // On iOS: use clientId for iOS OAuth client
          clientId: Platform.isIOS ? _googleiOSClientId : null,
          serverClientId: Platform.isAndroid ? _googleClientId : null,
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
  /// If user is already authenticated, this will LINK Google to their existing account.
  /// If user is not authenticated, this will create a new account or sign in.
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
      
      // Check if user is already authenticated
      final currentUser = _client.auth.currentUser;
      
      if (currentUser != null) {
        // User is logged in - LINK Google to existing account
        try {
          await _client.auth.linkIdentity(OAuthProvider.google);
          // Return current session after linking
          return AuthResponse(
            user: currentUser,
            session: _client.auth.currentSession,
          );
        } catch (e) {
          // If linking fails (e.g., Google account already linked to another user),
          // throw a more helpful error
          throw AuthException('This Google account is already linked to another account. Please sign in with that account first.');
        }
      }
      
      // User not logged in - sign in with Google (may create new account)
      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  /// Sign in with Apple using OAuth.
  /// 
  /// If user is already authenticated, this will LINK Apple to their existing account.
  /// If user is not authenticated, this will create a new account or sign in.
  /// Opens Apple Sign-In flow and exchanges the Apple ID token for a Supabase session.
  /// Throws [AuthException] if sign in fails or is cancelled.
  /// Only available on iOS 13+ and macOS 10.15+.
  Future<AuthResponse> signInWithApple() async {
    try {
      // Generate a random nonce for security
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);
      
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      
      final idToken = credential.identityToken;
      
      if (idToken == null) {
        throw const AuthException('Failed to get Apple ID token');
      }
      
      // Check if user is already authenticated
      final currentUser = _client.auth.currentUser;
      
      if (currentUser != null) {
        // User is logged in - LINK Apple to existing account
        try {
          await _client.auth.linkIdentity(OAuthProvider.apple);
          // Return current session after linking
          return AuthResponse(
            user: currentUser,
            session: _client.auth.currentSession,
          );
        } catch (e) {
          // If linking fails (e.g., Apple account already linked to another user),
          // throw a more helpful error
          throw AuthException('This Apple ID is already linked to another account. Please sign in with that account first.');
        }
      }
      
      // User not logged in - sign in with Apple (may create new account)
      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } catch (e) {
      rethrow;
    }
  }
  
  /// Generate a cryptographically secure random nonce for Apple Sign-In.
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }
  
  /// Generate SHA256 hash of a string.
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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
