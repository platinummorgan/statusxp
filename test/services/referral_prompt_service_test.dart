import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/services/referral_prompt_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('referral prompts are capped for seven days', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final service = ReferralPromptService();
    final start = DateTime.utc(2026, 7, 30);

    expect(await service.canShow(now: start, preferences: preferences), isTrue);
    await service.markShown(now: start, preferences: preferences);
    expect(
      await service.canShow(
        now: start.add(const Duration(days: 6)),
        preferences: preferences,
      ),
      isFalse,
    );
    expect(
      await service.canShow(
        now: start.add(const Duration(days: 7)),
        preferences: preferences,
      ),
      isTrue,
    );
  });
}
