import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;
import 'dart:async';
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
  
  // Hardcoded Google OAuth Client IDs - these are not sensitive and need to be in the app
  // Web client for backend/Supabase
  // Android client for Android OAuth flow
  // iOS client for iOS OAuth flow
  static const String _googleWebClientId = '395832690159-arutlclucst0mb9b3tctgn1m71i52q1v.apps.googleusercontent.com';
  static const String _googleAndroidClientId = '395832690159-fe24vs3m6udhe15ufm2m3jnn0k1pdrap.apps.googleusercontent.com';
  static const String _googleiOSClientId = '395832690159-psp0hu5uggjc7u2lmfhnmim016j2lhq2.apps.googleusercontent.com';
  
  AuthService(this._client) 
      : _googleSignIn = GoogleSignIn(
          // iOS needs explicit clientId
          clientId: Platform.isIOS ? _googleiOSClientId : null,
          // Use Web client for serverClientId - Supabase needs to verify with Web client secret
          // Android OAuth client is auto-discovered by package name + SHA-1
          serverClientId: _googleWebClientId,
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
      emailRedirectTo: 'com.statusxp.statusxp://login-callback',
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
      redirectTo: 'com.statusxp.statusxp://reset-password',
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
      if (Platform.isIOS || Platform.isMacOS) {
        return await _signInWithGoogleOAuth();
      }
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        throw const AuthException('Google Sign-In was cancelled');
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;
      
      if (idToken == null || accessToken == null) {
        throw const AuthException('Failed to get Google tokens');
      }
      
      final idTokenClaims = _extractClaimsFromIdToken(idToken);
      final idTokenNonce = idTokenClaims['nonce'] as String?;
      
      // Check if user is already authenticated
      final currentUser = _client.auth.currentUser;
      
      if (currentUser != null) {
        // User is logged in - LINK Google to existing account using ID/access tokens
        try {
          return await _client.auth.linkIdentityWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
            nonce: idTokenNonce,
          );
        } catch (e) {
          // If linking fails (e.g., Google account already linked to another user),
          // throw a more helpful error
          throw const AuthException('This Google account is already linked to another account. Please sign in with that account first.');
        }
      }
      
      // User not logged in - sign in with Google (may create new account)
      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
        nonce: idTokenNonce,
      );
    } on AuthException catch (e) {
      // Check if this is the "linked identity" error
      if (e.message.contains('already') || 
          e.message.contains('linked') ||
          e.message.contains('associated') ||
          e.message.contains('connected')) {
        throw const AuthException(
          'This Google account is linked to an existing account. Please sign in with your email/password first, then you can use Google Sign-In.',
        );
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
  
  /// Sign in with Apple using OAuth.
  /// 
  /// If user is already authenticated, this will LINK Apple to their existing account.
  /// If user is not authenticated, this will create a new account or sign in.
  /// Uses Supabase's OAuth flow which properly handles linked identities.
  /// Throws [AuthException] if sign in fails or is cancelled.
  /// Only available on iOS 13+ and macOS 10.15+.
  Future<AuthResponse> signInWithApple() async {
    try {
      // Check if user is already authenticated
      final currentUser = _client.auth.currentUser;
      const redirectTo = 'com.statusxp.statusxp://login-callback';
      
      if (currentUser != null) {
        // User is logged in - LINK Apple via Supabase OAuth flow
        try {
          await _client.auth.linkIdentity(
            OAuthProvider.apple,
            redirectTo: redirectTo,
          );
          return AuthResponse(
            user: currentUser,
            session: _client.auth.currentSession,
          );
        } catch (e) {
          throw const AuthException(
            'This Apple ID is already linked to another account. Please sign in with that account first.',
          );
        }
      }
      
      // User not logged in - use Supabase OAuth flow (handles linked identities correctly)
      final completer = Completer<AuthResponse>();
      late final StreamSubscription<AuthState> sub;
      sub = _client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn && data.session != null) {
          sub.cancel();
          completer.complete(
            AuthResponse(
              user: data.session!.user,
              session: data.session,
            ),
          );
        }
      });
      
      try {
        final launched = await _client.auth.signInWithOAuth(
          OAuthProvider.apple,
          redirectTo: redirectTo,
        );
        if (!launched) {
          await sub.cancel();
          throw const AuthException('Apple Sign-In was cancelled');
        }
      } catch (e) {
        await sub.cancel();
        rethrow;
      }
      
      return completer.future.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          sub.cancel();
          throw const AuthException('Apple Sign-In timed out');
        },
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
  
  /// Extracts JWT claims from an id_token, if present.
  Map<String, dynamic> _extractClaimsFromIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) {
        return <String, dynamic>{};
      }
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final data = jsonDecode(payload);
      return data is Map<String, dynamic> ? data : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
  
  /// Extract the nonce from an ID token.
  String? _extractNonceFromIdToken(String idToken) {
    try {
      final claims = _extractClaimsFromIdToken(idToken);
      return claims['nonce'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<AuthResponse> _signInWithGoogleOAuth() async {
    final currentUser = _client.auth.currentUser;
    const redirectTo = 'com.statusxp.statusxp://login-callback';
    
    if (currentUser != null) {
      // Link Google via Supabase OAuth flow to avoid token nonce issues on iOS.
      try {
        await _client.auth.linkIdentity(
          OAuthProvider.google,
          redirectTo: redirectTo,
        );
        return AuthResponse(
          user: currentUser,
          session: _client.auth.currentSession,
        );
      } catch (e) {
        throw const AuthException(
          'This Google account is already linked to another account. Please sign in with that account first.',
        );
      }
    }
    
    final completer = Completer<AuthResponse>();
    late final StreamSubscription<AuthState> sub;
    sub = _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        sub.cancel();
        completer.complete(
          AuthResponse(
            user: data.session!.user,
            session: data.session,
          ),
        );
      }
    });
    
    try {
      final launched = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
      if (!launched) {
        await sub.cancel();
        throw const AuthException('Google Sign-In was cancelled');
      }
    } catch (e) {
      await sub.cancel();
      rethrow;
    }
    
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () {
        sub.cancel();
        throw const AuthException('Google Sign-In timed out');
      },
    );
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
