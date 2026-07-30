import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/utils/supabase_guard.dart';

enum PremiumActivationTask { analytics, radar, goal, premiumSync }

class PremiumActivationService {
  static String _key(String userId, PremiumActivationTask task) =>
      'premium_activation_${userId}_${task.name}';

  Future<Set<PremiumActivationTask>> completed(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return PremiumActivationTask.values
        .where((task) => preferences.getBool(_key(userId, task)) ?? false)
        .toSet();
  }

  Future<void> complete(String userId, PremiumActivationTask task) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _key(userId, task);
    if (preferences.getBool(key) == true) return;
    await preferences.setBool(key, true);
    AnalyticsService().logCustomEvent(
      eventName: 'premium_activation_task_completed',
      parameters: {'task': task.name},
    );
  }

  Future<void> completeCurrentUser(PremiumActivationTask task) async {
    final userId = tryGetSupabaseClient()?.auth.currentUser?.id;
    if (userId != null) await complete(userId, task);
  }
}
