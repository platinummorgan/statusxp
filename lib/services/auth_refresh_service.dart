import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service that manages auth token refresh with proper network error handling
class AuthRefreshService {
  final SupabaseClient _client;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  
  AuthRefreshService(this._client);
  
  /// Start periodic token refresh checks (every 5 minutes)
  void startPeriodicRefresh() {
    stopPeriodicRefresh();
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshIfNeeded(),
    );
  }
  
  /// Stop periodic refresh
  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
  
  /// Proactively refresh session when app resumes from background
  /// This prevents "Session expired" errors when returning to the app
  /// Returns Future<void> that never throws - all errors are caught internally
  Future<void> refreshIfNeededOnResume() async {
    try {
      // Add a connectivity check delay when called on resume
      await Future.delayed(const Duration(milliseconds: 500));
      await _refreshIfNeeded();
    } catch (e) {
      // Never throw - silently handle all errors
      print('Session refresh on resume failed (will retry automatically): $e');
    }
  }
  
  /// Manually trigger token refresh with error handling
  Future<void> _refreshIfNeeded() async {
    // Prevent concurrent refreshes
    if (_isRefreshing) return;
    
    try {
      _isRefreshing = true;
      
      final session = _client.auth.currentSession;
      if (session == null) return;
      
      // Check if token is expired or about to expire (within 10 minutes)
      final expiresAtEpoch = session.expiresAt;
      if (expiresAtEpoch == null) {
        // Older or corrupted sessions can lack expiresAt, especially on web.
        if (session.refreshToken == null) {
          print('Session missing expiresAt and refreshToken; skipping refresh check.');
          return;
        }
        await _refreshWithRetry();
        return;
      }
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        expiresAtEpoch * 1000,
      );
      final timeUntilExpiry = expiresAt.difference(DateTime.now());
      
      // Refresh if expired or expiring soon
      if (timeUntilExpiry.inMinutes < 10) {
        print('Token expiring in ${timeUntilExpiry.inMinutes} minutes, refreshing...');
        await _refreshWithRetry();
      }
    } catch (e) {
      // Silently fail - don't show error to user during background refresh
      print('Background token refresh failed: $e');
    } finally {
      _isRefreshing = false;
    }
  }
  
  /// Refresh token with retry logic and network error handling
  Future<void> _refreshWithRetry({int maxRetries = 3}) async {
    int retryCount = 0;
    
    while (retryCount < maxRetries) {
      try {
        await _client.auth.refreshSession();
        print('Auth token refreshed successfully');
        return;
      } catch (e) {
        retryCount++;
        
        // Check if it's a network error
        if (e.toString().contains('SocketException') || 
            e.toString().contains('Failed host lookup') ||
            e.toString().contains('ClientException')) {
          
          if (retryCount < maxRetries) {
            // Exponential backoff: 2s, 4s, 8s
            final delaySeconds = 2 * retryCount;
            print('Network error during refresh, retrying in ${delaySeconds}s... (attempt $retryCount/$maxRetries)');
            await Future.delayed(Duration(seconds: delaySeconds));
          } else {
            print('Max retries reached for token refresh');
            // Don't throw - just log and continue
            return;
          }
        } else {
          // Non-network error, don't retry
          print('Non-network error during refresh: $e');
          return;
        }
      }
    }
  }
  
  /// Dispose and clean up
  void dispose() {
    stopPeriodicRefresh();
  }
}
