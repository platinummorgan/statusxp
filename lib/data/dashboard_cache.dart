import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/domain/dashboard_stats.dart';

/// Display-only stats, scoped to an account. Never used for entitlements.
class DashboardCache {
  String _key(String userId) => 'dashboard_stats_v1_$userId';

  Future<DashboardStats?> read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(userId));
      return raw == null
          ? null
          : DashboardStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String userId, DashboardStats stats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(userId), jsonEncode(stats.toJson()));
    } catch (_) {
      // Storage failures must not prevent fresh stats from being displayed.
    }
  }
}
