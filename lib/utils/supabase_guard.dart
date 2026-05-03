import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns the initialized Supabase client when available.
///
/// During widget tests (or partial startup failures), Supabase may not be
/// initialized. This helper prevents assertion crashes from direct access to
/// `Supabase.instance.client`.
SupabaseClient? tryGetSupabaseClient() {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

bool isSupabaseInitialized() => tryGetSupabaseClient() != null;
