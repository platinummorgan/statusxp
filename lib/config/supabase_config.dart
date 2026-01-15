import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase configuration
class SupabaseConfig {
  /// Get Supabase URL from environment
  /// First checks compile-time --dart-define, then falls back to .env file
  static String get supabaseUrl {
    const compiledValue = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
    if (compiledValue.isNotEmpty) return compiledValue;
    return dotenv.env['SUPABASE_URL'] ?? '';
  }

  /// Get Supabase anon key from environment
  /// First checks compile-time --dart-define, then falls back to .env file
  static String get supabaseAnonKey {
    const compiledValue = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
    if (compiledValue.isNotEmpty) return compiledValue;
    return dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  }
}
