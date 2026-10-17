import 'package:statusxp/services/achievement_checker_service.dart';

/// Existing sync screens use the same server rules as the achievements screen.
class PlatformAchievementChecker extends AchievementCheckerService {
  PlatformAchievementChecker(super.client);
}
