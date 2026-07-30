import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/services/premium_activation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('tracks Premium activation separately for each user', () async {
    SharedPreferences.setMockInitialValues({});
    final service = PremiumActivationService();

    await service.complete('user-one', PremiumActivationTask.analytics);
    await service.complete('user-one', PremiumActivationTask.radar);

    expect(await service.completed('user-one'), {
      PremiumActivationTask.analytics,
      PremiumActivationTask.radar,
    });
    expect(await service.completed('user-two'), isEmpty);
  });
}
