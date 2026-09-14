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
