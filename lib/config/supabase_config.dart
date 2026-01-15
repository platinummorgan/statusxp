/// Supabase configuration using compile-time constants
class SupabaseConfig {
  /// Get Supabase URL from --dart-define at compile time
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://ksriqcmumjkemtfjuedm.supabase.co',
  );

  /// Get Supabase anon key from --dart-define at compile time
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtzcmlxY211bWprZW10Zmp1ZWRtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ3MTQxODQsImV4cCI6MjA4MDI5MDE4NH0.svxzehEtMDUQjF-stp7GL_LmRKQOFu_6PxI0IgbLVoQ',
  );
}
