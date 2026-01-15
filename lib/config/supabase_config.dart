import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase configuration
/// Priority: 1) --dart-define (production builds), 2) .env (local dev), 3) hardcoded defaults
class SupabaseConfig {
  /// Get Supabase URL from environment
  static String get supabaseUrl {
    // First check compile-time --dart-define (production builds)
    const compiledValue = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    if (compiledValue.isNotEmpty) return compiledValue;
    
    // Then check .env (local dev) - safely handle case where dotenv not loaded
    try {
      final envValue = dotenv.env['SUPABASE_URL'];
      if (envValue != null && envValue.isNotEmpty) return envValue;
    } catch (e) {
      // dotenv not loaded - continue to fallback
    }
    
    // Finally fall back to hardcoded production default
    return 'https://ksriqcmumjkemtfjuedm.supabase.co';
  }

  /// Get Supabase anon key from environment
  static String get supabaseAnonKey {
    // First check compile-time --dart-define (production builds)
    const compiledValue = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    if (compiledValue.isNotEmpty) return compiledValue;
    
    // Then check .env (local dev) - safely handle case where dotenv not loaded
    try {
      final envValue = dotenv.env['SUPABASE_ANON_KEY'];
      if (envValue != null && envValue.isNotEmpty) return envValue;
    } catch (e) {
      // dotenv not loaded - continue to fallback
    }
    
    // Finally fall back to hardcoded production default
    return 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MTQxODQsImV4cCI6MjA4MDI5MDE4NH0.svxzehEtMDUQjF-stp7GL_LmRKQOFu_6PxI0IgbLVoQ';
  }
}
