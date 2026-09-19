import 'package:supabase_flutter/supabase_flutter.dart';

/// Prefer effective entitlements, supporting the existing server during rollout.
Future<Map<String, dynamic>?> readPremiumEntitlement(
  SupabaseClient client,
) async {
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;
  Map<String, dynamic>? result;
  try {
    final response = await client.rpc('get_my_premium_entitlement');
    result = response == null
        ? null
        : Map<String, dynamic>.from(response as Map);
  } on PostgrestException catch (error) {
    if (error.code != 'PGRST202') rethrow;
    result = await client
        .from('user_premium_status')
        .select('is_premium,premium_since,premium_expires_at,premium_source')
        .eq('user_id', userId)
        .maybeSingle();
  }
  return client.auth.currentUser?.id == userId ? result : null;
}

/// Shared client interpretation of the server's effective entitlement row.
/// Null expiry preserves existing non-expiring/legacy grants during migration.
bool hasActivePremium(Map<String, dynamic>? entitlement, {DateTime? now}) {
  if (entitlement?['is_premium'] != true) return false;
  final rawExpiry = entitlement?['premium_expires_at'];
  if (rawExpiry == null) return true;
  if (rawExpiry is! String) return false;
  final expiry = DateTime.tryParse(rawExpiry);
  return expiry != null && expiry.isAfter(now ?? DateTime.now());
}
