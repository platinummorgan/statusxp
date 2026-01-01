# Release Notes - Version 1.0.0+41

## 🎉 Happy New Year 2026 Update!

## Network Resilience Improvements

### Authentication
- **Fixed intermittent DNS lookup errors** during navigation
  - Disabled automatic token refresh to prevent network errors while navigating
  - Implemented manual token refresh service with intelligent retry logic
  - Added exponential backoff for network errors (2s, 4s, 8s delays)
  - Network errors no longer show authentication error screens to users

### Error Handling
- Improved network error detection for `SocketException` and DNS lookup failures
- PSN and Xbox sync services now gracefully handle temporary network issues
- Dashboard data loading silently retries on network errors instead of showing error dialogs
- Better distinction between authentication errors (require re-login) and network errors (auto-retry)

## Technical Improvements
- Created `AuthRefreshService` for controlled token refresh management
- Configured Supabase with `autoRefreshToken: false` to prevent background refresh errors
- Added network error handling to PSN and Xbox service session refresh logic
- Token refresh now happens every 5 minutes with smart expiry checking (within 10 minutes of expiry)
- Auth refresh service automatically starts/stops based on user login state

## User Experience
- **Smoother navigation**: No more authentication error popups when navigating between screens
- App continues working even with spotty network connectivity
- Background token refresh failures are silent and don't interrupt user experience
- Only actual authentication failures prompt users to sign in again

## Developer Notes
- Auth refresh service is globally accessible via `authRefreshService`
- New service file: `lib/services/auth_refresh_service.dart`
- Updated `main.dart` with improved Supabase initialization configuration
- Added network error handling patterns in `psn_service.dart` and `xbox_service.dart`
