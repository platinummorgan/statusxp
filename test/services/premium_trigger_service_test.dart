import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/services/premium_trigger_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a contextual cooldown offer', () {
    final offer = premiumOfferFor(
      PremiumTrigger.syncCooldown,
      platform: 'Steam',
    );

    expect(offer.source, 'sync_cooldown_Steam');
    expect(offer.title, contains('Sync sooner'));
    expect(offer.message, contains('15 minutes'));
  });

  test('caps offers globally and by trigger source', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final service = PremiumTriggerService();
    final start = DateTime.utc(2026, 7, 30, 12);

    expect(
      await service.canShow('ai_limit', now: start, preferences: preferences),
      isTrue,
    );
    await service.markShown('ai_limit', now: start, preferences: preferences);

    expect(
      await service.canShow(
        'sync_cooldown_Steam',
        now: start.add(const Duration(hours: 23)),
        preferences: preferences,
      ),
      isFalse,
    );
    expect(
      await service.canShow(
        'ai_limit',
        now: start.add(const Duration(days: 2)),
        preferences: preferences,
      ),
      isFalse,
    );
    expect(
      await service.canShow(
        'ai_limit',
        now: start.add(const Duration(days: 8)),
        preferences: preferences,
      ),
      isTrue,
    );
  });
}
