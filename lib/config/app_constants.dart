/// Application-wide constants
/// 
/// Centralized location for constant values used throughout the app.
class AppConstants {
  /// Demo user ID used when no user is authenticated.
  /// 
  /// This allows the app to function in demo mode with sample data
  /// when users are not logged in.
  static const String demoUserId = 'demo-user-id';
  
  AppConstants._(); // Prevent instantiation
}
