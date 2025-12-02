import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing Supabase authentication.
/// 
/// Provides a clean abstraction over Supabase Auth for email/password authentication,
/// session management, and auth state changes.
class AuthService {
  final SupabaseClient _client;
  
  AuthService(this._client);
  
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
