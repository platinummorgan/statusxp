import 'package:supabase_flutter/supabase_flutter.dart';

/// One server-side rule set evaluates the complete, verified unlock history.
class AchievementCheckerService {
  final SupabaseClient _client;

  AchievementCheckerService(SupabaseClient client) : _client = client;

  Future<List<String>> checkAndUnlockAchievements(String userId) async {
    final result = await _client.rpc(
      'reconcile_app_achievements',
      params: {'p_user_id': userId},
    );
    if (result is! List) {
      throw const FormatException('Invalid app achievement check response');
    }
    return result
        .map((row) => (row as Map)['achievement_id'] as String)
        .toList();
  }
}
