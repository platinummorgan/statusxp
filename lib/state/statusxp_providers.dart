import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/game_edit_service.dart';
import '../data/repositories/game_repository.dart';
import '../data/repositories/user_stats_repository.dart';
import '../domain/game.dart';
import '../domain/user_stats.dart';
import '../domain/user_stats_calculator.dart';

/// Provider for the GameRepository instance.
/// 
/// This uses LocalFileGameRepository to persist games to a JSON file.
final gameRepositoryProvider = Provider<GameRepository>((ref) {
  return LocalFileGameRepository();
});

/// Provider for the UserStatsRepository instance.
/// 
/// This uses LocalFileUserStatsRepository to persist user stats to a JSON file.
final userStatsRepositoryProvider = Provider<UserStatsRepository>((ref) {
  return LocalFileUserStatsRepository();
});

/// FutureProvider for loading all games.
/// 
/// This provider loads games asynchronously from the GameRepository.
/// On first run, it will seed from sample_data.dart.
final gamesProvider = FutureProvider<List<Game>>((ref) async {
  final repository = ref.watch(gameRepositoryProvider);
  return repository.loadGames();
});

/// FutureProvider for loading user statistics.
/// 
/// This provider loads user stats asynchronously from the UserStatsRepository.
/// On first run, it will seed from sample_data.dart.
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final repository = ref.watch(userStatsRepositoryProvider);
  return repository.loadUserStats();
});

/// Provider for the UserStatsCalculator.
/// 
/// This calculator recomputes user stats from a list of games.
final userStatsCalculatorProvider = Provider<UserStatsCalculator>((ref) {
  return const UserStatsCalculator();
});

/// Provider for the GameEditService.
/// 
/// This service handles game updates with automatic stats recalculation.
final gameEditServiceProvider = Provider<GameEditService>((ref) {
  return GameEditService(
    gameRepository: ref.watch(gameRepositoryProvider),
    userStatsRepository: ref.watch(userStatsRepositoryProvider),
    statsCalculator: ref.watch(userStatsCalculatorProvider),
  );
});

/// Extension to refresh core data providers after mutations.
extension StatusXPRefresh on WidgetRef {
  void refreshCoreData() {
    invalidate(gamesProvider);
    invalidate(userStatsProvider);
  }
}
