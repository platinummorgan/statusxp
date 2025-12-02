import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth/auth_service.dart';
import '../data/data_migration_service.dart';
import '../data/repositories/supabase_game_repository.dart';
import '../data/repositories/supabase_trophies_repository.dart';
import '../data/repositories/supabase_user_stats_repository.dart';
import '../data/supabase_game_edit_service.dart';
import '../domain/game.dart';
import '../domain/user_stats.dart';
import '../domain/user_stats_calculator.dart';

/// Provider for the Supabase client instance.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for the AuthService instance.
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthService(client);
});

/// StreamProvider for authentication state changes.
/// 
/// Emits whenever the user signs in, signs out, or the token refreshes.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Provider for the current authenticated user ID.
/// 
/// Returns null if no user is authenticated.
/// No fallback - authentication is now required.
final currentUserIdProvider = Provider<String?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser?.id;
});

/// Provider for the DataMigrationService instance.
final dataMigrationServiceProvider = Provider<DataMigrationService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return DataMigrationService(client);
});

/// Provider for the SupabaseGameRepository instance.
final gameRepositoryProvider = Provider<SupabaseGameRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseGameRepository(client);
});

/// Provider for the SupabaseUserStatsRepository instance.
final userStatsRepositoryProvider = Provider<SupabaseUserStatsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseUserStatsRepository(client);
});

/// Provider for the SupabaseTrophiesRepository instance.
final trophiesRepositoryProvider = Provider<SupabaseTrophiesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseTrophiesRepository(client);
});

/// FutureProvider for loading all games for the current user.
/// 
/// This provider loads games asynchronously from Supabase.
final gamesProvider = FutureProvider<List<Game>>((ref) async {
  final repository = ref.watch(gameRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return [];
  }
  
  return repository.getGamesForUser(userId);
});

/// FutureProvider for loading user statistics for the current user.
/// 
/// This provider loads user stats asynchronously from Supabase.
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final repository = ref.watch(userStatsRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return const UserStats(
      username: 'Guest',
      totalPlatinums: 0,
      totalGamesTracked: 0,
      totalTrophies: 0,
      hardestPlatGame: 'None',
      rarestTrophyName: 'None',
      rarestTrophyRarity: 0.0,
    );
  }
  
  return repository.getUserStats(userId);
});

/// Provider for the UserStatsCalculator.
/// 
/// This calculator recomputes user stats from a list of games.
final userStatsCalculatorProvider = Provider<UserStatsCalculator>((ref) {
  return const UserStatsCalculator();
});

/// Provider for the SupabaseGameEditService.
/// 
/// This service handles game updates with automatic stats recalculation.
/// Requires authenticated user.
final gameEditServiceProvider = Provider<SupabaseGameEditService>((ref) {
  final gameRepo = ref.watch(gameRepositoryProvider);
  final statsRepo = ref.watch(userStatsRepositoryProvider);
  final calculator = ref.watch(userStatsCalculatorProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    throw StateError('User must be authenticated to edit games');
  }
  
  return SupabaseGameEditService(
    gameRepository: gameRepo,
    userStatsRepository: statsRepo,
    statsCalculator: calculator,
    userId: userId,
  );
});

/// Extension to refresh core data providers after mutations.
extension StatusXPRefresh on WidgetRef {
  void refreshCoreData() {
    invalidate(gamesProvider);
    invalidate(userStatsProvider);
  }
}
