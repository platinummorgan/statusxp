import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Service for managing Supabase authentication.
/// 
/// Provides a clean abstraction over Supabase Auth for email/password authentication,
/// Google Sign-In, session management, and auth state changes.
class AuthService {
  final SupabaseClient _client;
  final GoogleSignIn _googleSignIn;
  
  // Hardcoded Google Client ID - this is not sensitive and needs to be in the app
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
