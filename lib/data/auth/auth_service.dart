import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:statusxp/utils/html.dart' as html;

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
          // iOS needs explicit clientId (web/Android use null)
          clientId: (!kIsWeb && Platform.isIOS) ? _googleiOSClientId : null,
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
    const redirectUrl = kIsWeb 
        ? 'https://statusxp.com/login-callback'
        : 'com.statusxp.statusxp://login-callback';
    return await _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: redirectUrl,
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
    const redirectUrl = kIsWeb 
        ? 'https://statusxp.com/reset-password'
        : 'com.statusxp.statusxp://reset-password';
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: redirectUrl,
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
  /// Clears the session and revokes the refresh token on the server.
  /// This ensures that any stored refresh token becomes invalid and cannot be
  /// used to restore the session via biometric authentication.
  Future<void> signOut() async {
    print('=== LOGOUT CALLED ===');
    
    // Supabase's signOut() automatically invalidates the refresh token on the server
    await _client.auth.signOut(scope: SignOutScope.global);
    
    print('Supabase signOut completed');
    
    // On web, nuclear option: clear ALL localStorage after signOut
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 300));
      html.window.localStorage.clear();
      html.window.sessionStorage.clear();
      print('ALL storage cleared on web');
    }
  }
  
  /// Sign in with Google using OAuth.
  /// 
  /// If user is already authenticated, this will LINK Google to their existing account.
  /// If user is not authenticated, this will create a new account or sign in.
  /// Opens Google Sign-In flow and exchanges the Google ID token for a Supabase session.
  /// Throws [AuthException] if sign in fails or is cancelled.
  Future<AuthResponse> signInWithGoogle() async {
    try {
      // On web, use Supabase OAuth redirect flow (native plugin doesn't work)
      if (kIsWeb) {
        // Keep redirect on the current origin so the PKCE verifier matches localStorage.
        final redirectUrl = html.window.location.origin;
        final success = await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
          authScreenLaunchMode: LaunchMode.platformDefault,
        );
        if (!success) {
          throw const AuthException('Google Sign-In failed to start');
        }
        // On web, OAuth opens a redirect - return empty response
        // The actual session will be established after redirect
        return AuthResponse();
      }
      
      // On iOS/macOS, use dedicated OAuth flow
      if (Platform.isIOS || Platform.isMacOS) {
        return await _signInWithGoogleOAuth();
      }
      
      // On Android, use GoogleSignIn plugin for native flow
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
  
  /// Sign in with Apple using native Sign In with Apple.
  /// 
  /// If user is already authenticated, this will LINK Apple to their existing account.
  /// If user is not authenticated, this will create a new account or sign in.
  /// Uses native Sign In with Apple API for better reliability.
  /// Throws [AuthException] if sign in fails or is cancelled.
  /// Only available on iOS 13+ and macOS 10.15+.
  Future<AuthResponse> signInWithApple() async {
    // On web, use OAuth flow instead of native Sign In with Apple
    if (kIsWeb) {
      const redirectUrl = 'https://statusxp.com/login-callback';
      final success = await _client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: redirectUrl,
      );
      if (!success) {
        throw const AuthException('Apple Sign-In failed on web');
      }
      // OAuth redirects away, so we never actually reach here in success case
      // This is just for type safety
      return AuthResponse();
    }
    
    // Native flow for iOS/Android
    try {
      // Generate nonce for security
      final rawNonce = _generateNonce();
      final hashedNonce = _sha256ofString(rawNonce);
      
      // Request Apple Sign In
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );
      
      final idToken = credential.identityToken;
      if (idToken == null) {
        throw const AuthException('Apple Sign-In failed - no identity token received');
      }
      
      // Check if user is already authenticated
      final currentUser = _client.auth.currentUser;
      
      if (currentUser != null) {
        // User is logged in - LINK Apple to existing account
        try {
          return await _client.auth.linkIdentityWithIdToken(
            provider: OAuthProvider.apple,
            idToken: idToken,
            nonce: rawNonce,
          );
        } catch (e) {
          throw const AuthException(
            'This Apple ID is already linked to another account. Please sign in with that account first.',
          );
        }
      }
      
      // User not logged in - sign in with Apple
      return await _client.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AuthException('Apple Sign-In was cancelled');
      }
      throw AuthException('Apple Sign-In failed: ${e.message}');
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
    const redirectTo = kIsWeb 
        ? 'https://statusxp.com/login-callback'
        : 'com.statusxp.statusxp://login-callback';
    
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
  /// Returns true on iOS 13+, macOS 10.15+, and web (uses JavaScript).
  Future<bool> get isAppleSignInAvailable async {
    try {
      // Apple Sign-In works on web via JavaScript SDK
      if (kIsWeb) return true;
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
  
  /// Get the current session's refresh token
  /// 
  /// Returns the refresh token if there is an active session, null otherwise.
  /// This refresh token should be stored securely (encrypted by OS) for biometric re-authentication.
  String? get refreshToken => _client.auth.currentSession?.refreshToken;
  
  /// Get the current session's expiry time
  /// 
  /// Returns when the refresh token expires, requiring full re-authentication.
  /// Typically refresh tokens last 30-90 days.
  DateTime? get refreshTokenExpiry {
    final expiresAt = _client.auth.currentSession?.expiresAt;
    if (expiresAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
  }
  
  /// Exchange a stored refresh token for a new access token
  /// 
  /// This should be called after successful biometric authentication to restore
  /// the user's session without requiring username/password.
  /// 
  /// Returns true if the session was successfully restored, false if the refresh
  /// token is invalid or expired.
  /// 
  /// Throws [AuthException] if the refresh operation fails due to network or other errors.
  Future<bool> restoreSessionFromRefreshToken(String refreshToken) async {
    try {
      // Supabase's setSession will automatically refresh if the refresh token is valid
      final response = await _client.auth.setSession(refreshToken);
      
      if (response.session == null) {
        // Refresh token was invalid or expired
        return false;
      }
      
      return true;
    } on AuthException catch (e) {
      // Invalid or expired refresh token
      if (e.message.contains('refresh_token') || 
          e.message.contains('Invalid') ||
          e.message.contains('expired')) {
        return false;
      }
      // Other auth errors should be rethrown
      rethrow;
    } catch (e) {
      // Network or other errors
      rethrow;
    }
  }
  
  /// Sign out and invalidate the refresh token on the server
  /// 
  /// This ensures that any stored refresh token becomes invalid and cannot be
  /// used to restore the session via biometric authentication.
  /// 
  /// This is the recommended way to sign out when using biometric authentication.
  Future<void> signOutAndInvalidateToken() async {
    // Supabase's signOut() automatically invalidates the refresh token on the server
    await _client.auth.signOut();
  }
}
