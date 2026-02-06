import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:statusxp/data/auth/auth_service.dart';
import 'package:statusxp/data/auth/biometric_auth_service.dart';
import 'package:statusxp/data/psn_service.dart';
import 'package:statusxp/data/xbox_service.dart';
import 'package:statusxp/data/twitch_service.dart';
import 'package:statusxp/data/repositories/supabase_game_repository.dart';
import 'package:statusxp/data/repositories/supabase_trophies_repository.dart';
import 'package:statusxp/data/repositories/supabase_user_stats_repository.dart';
import 'package:statusxp/data/repositories/supabase_dashboard_repository.dart';
import 'package:statusxp/data/repositories/trophy_room_repository.dart';
import 'package:statusxp/data/repositories/unified_games_repository.dart';
import 'package:statusxp/data/supabase_game_edit_service.dart';
import 'package:statusxp/services/platform_achievement_checker.dart';
import 'package:statusxp/services/trophy_help_service.dart';
import 'package:statusxp/services/achievement_comment_service.dart';
import 'package:statusxp/domain/game.dart';
import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:statusxp/domain/trophy_room_data.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/domain/user_stats.dart';
import 'package:statusxp/domain/user_stats_calculator.dart';

/// Provider for the Supabase client instance.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Provider for the AuthService instance.
final authServiceProvider = Provider<AuthService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthService(client);
});

/// Provider for the BiometricAuthService instance.
final biometricAuthServiceProvider = Provider<BiometricAuthService>((ref) {
  return BiometricAuthService();
});

/// Provider for the TrophyHelpService instance.
final trophyHelpServiceProvider = Provider<TrophyHelpService>((ref) {
  return TrophyHelpService(ref.read(supabaseClientProvider));
});

/// Provider for the AchievementCommentService instance.
final achievementCommentServiceProvider = Provider<AchievementCommentService>((ref) {
  return AchievementCommentService(ref.read(supabaseClientProvider));
});

/// StateProvider for requesting a local biometric lock.
/// 
/// Used to trigger a lock screen without signing out.
final biometricLockRequestedProvider = StateProvider<bool>((ref) {
  return false;
});

/// StateProvider for granting a one-time biometric unlock after sign-in.
final biometricUnlockGrantedProvider = StateProvider<bool>((ref) {
  return false;
});

/// StreamProvider for authentication state changes.
/// 
/// Emits whenever the user signs in, signs out, or the token refreshes.
/// Network errors during token refresh are silently handled to prevent error dialogs.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.handleError((error, stackTrace) {
    // Silently handle network errors during token refresh
    // These are temporary and Supabase will automatically retry
    if (error.toString().contains('SocketException') ||
        error.toString().contains('Failed host lookup') ||
        error.toString().contains('AuthRetryableFetchException') ||
        error.toString().contains('No address associated with hostname')) {
      // Don't propagate network errors - just log them
      print('Network error during auth state change (will auto-retry): $error');
      return;
    }
    // Re-throw other errors (like actual auth failures)
    throw error;
  });
});

/// Provider for the current user ID.
/// 
/// Returns the authenticated user's ID, or null if not authenticated.
final currentUserIdProvider = Provider<String?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser?.id;
});

/// Provider for the PSNService instance.
final psnServiceProvider = Provider<PSNService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PSNService(client);
});

/// Provider for the XboxService instance.
final xboxServiceProvider = Provider<XboxService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return XboxService(client);
});

/// Provider for the TwitchService instance.
final twitchServiceProvider = Provider<TwitchService>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return TwitchService(client);
});

/// StreamProvider for PSN sync status.
/// 
/// Watches sync status and updates UI automatically during syncs.
final psnSyncStatusProvider = StreamProvider<PSNSyncStatus>((ref) {
  final psnService = ref.watch(psnServiceProvider);
  return psnService.watchSyncStatus();
});

/// StreamProvider for Xbox sync status.
/// 
/// Watches sync status and updates UI automatically during syncs.
final xboxSyncStatusProvider = StreamProvider<XboxSyncStatus>((ref) {
  final xboxService = ref.watch(xboxServiceProvider);
  return xboxService.watchSyncStatus();
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

/// Provider for the TrophyRoomRepository instance.
final trophyRoomRepositoryProvider = Provider<TrophyRoomRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return TrophyRoomRepository(client);
});

/// Provider for the Platform Achievement Checker instance.
final platformAchievementCheckerProvider = Provider<PlatformAchievementChecker>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PlatformAchievementChecker(client);
});

/// Provider for the SupabaseDashboardRepository instance.
final dashboardRepositoryProvider = Provider<SupabaseDashboardRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseDashboardRepository(client);
});

/// Provider for the UnifiedGamesRepository instance.
final unifiedGamesRepositoryProvider = Provider<UnifiedGamesRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return UnifiedGamesRepository(client);
});

/// FutureProvider for loading games for the current user.
/// 
/// This provider loads games asynchronously from Supabase.
/// Returns empty list if no user is authenticated.
final gamesProvider = FutureProvider<List<Game>>((ref) async {
  final repository = ref.watch(gameRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return [];
  }
  
  return repository.getGamesForUser(userId);
});

/// FutureProvider for loading unified cross-platform games.
/// 
/// Groups games by title across all platforms (PSN/Xbox/Steam).
final unifiedGamesProvider = FutureProvider<List<UnifiedGame>>((ref) async {
  final repository = ref.watch(unifiedGamesRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return [];
  }
  
  return repository.getUnifiedGames(userId);
});

/// FutureProvider for loading user statistics for the current user.
/// 
/// This provider loads user stats asynchronously from Supabase.
/// Throws if no user is authenticated (should not happen in normal flow).
final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final repository = ref.watch(userStatsRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    throw Exception('Cannot load stats: No authenticated user');
  }
  
  return repository.getUserStats(userId);
});

/// FutureProvider for loading dashboard statistics for the current user.
/// 
/// This provider loads cross-platform dashboard stats including StatusXP score.
/// Returns empty stats if no user is authenticated.
final dashboardStatsProvider = FutureProvider<DashboardStats?>((ref) async {
  final repository = ref.watch(dashboardRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return null;
  }
  
  try {
    return await repository.getDashboardStats(userId);
  } catch (e) {
    // Silently return null on network errors to prevent error dialogs
    if (e.toString().contains('SocketException') || 
        e.toString().contains('Failed host lookup') ||
        e.toString().contains('AuthRetryableFetchException')) {
      return null;
    }
    rethrow;
  }
});

/// FutureProvider for loading Trophy Room data for the current user.
/// 
/// Fetches platinum trophies, ultra-rare trophies, and recent unlocks.
final trophyRoomDataProvider = FutureProvider<TrophyRoomData>((ref) async {
  final repository = ref.watch(trophyRoomRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    throw Exception('Cannot load trophy room: No authenticated user');
  }
  
  // Fetch all data in parallel for performance
  final results = await Future.wait([
    repository.getPlatinumTrophies(userId),
    repository.getUltraRareTrophies(userId, limit: 5),
    repository.getRecentTrophies(userId, limit: 10),
  ]);
  
  return TrophyRoomData(
    platinums: results[0].map((m) => PlatinumTrophy.fromMap(m)).toList(),
    ultraRareTrophies: results[1].map((m) => UltraRareTrophy.fromMap(m)).toList(),
    recentTrophies: results[2].map((m) => RecentTrophy.fromMap(m)).toList(),
  );
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
final gameEditServiceProvider = Provider<SupabaseGameEditService?>((ref) {
  final gameRepo = ref.watch(gameRepositoryProvider);
  final statsRepo = ref.watch(userStatsRepositoryProvider);
  final calculator = ref.watch(userStatsCalculatorProvider);
  final userId = ref.watch(currentUserIdProvider);
  
  if (userId == null) {
    return null;
  }
  
  return SupabaseGameEditService(
    gameRepository: gameRepo,
    userStatsRepository: statsRepo,
    statsCalculator: calculator,
    userId: userId,
  );
});

/// Provider for loading all leaderboard ranks (global, PSN, Xbox, Steam) in parallel
/// Returns a map with rank data for efficient Status Poster loading
final leaderboardRanksProvider = FutureProvider<Map<String, int?>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  
  if (userId == null) {
    return {
      'global': null,
      'psn': null,
      'xbox': null,
      'steam': null,
    };
  }
  
  // Fetch all ranks in parallel for optimal performance
  final results = await Future.wait([
    // Global rank - use leaderboard_cache table (same as leaderboard screen)
    client.from('leaderboard_cache').select('user_id,total_statusxp').gt('total_statusxp', 0).order('total_statusxp', ascending: false),
    // PSN leaderboard - fetch all to calculate rank client-side
    client.from('psn_leaderboard_cache').select('user_id,platinum_count,gold_count,silver_count,bronze_count').order('platinum_count', ascending: false).order('gold_count', ascending: false).order('silver_count', ascending: false).order('bronze_count', ascending: false),
    // Xbox leaderboard - fetch all to calculate rank client-side  
    client.from('xbox_leaderboard_cache').select('user_id,gamerscore,achievement_count').order('gamerscore', ascending: false).order('achievement_count', ascending: false),
    // Steam leaderboard - fetch all to calculate rank client-side
    client.from('steam_leaderboard_cache').select('user_id,achievement_count').order('achievement_count', ascending: false),
  ]);
  
  // Calculate Global rank
  int? globalRank;
  final globalList = results[0] as List;
  final globalIndex = globalList.indexWhere((row) => row['user_id'] == userId);
  globalRank = globalIndex >= 0 ? globalIndex + 1 : null;
  
  // Calculate PSN rank
  int? psnRank;
  final psnList = results[1] as List;
  final psnIndex = psnList.indexWhere((row) => row['user_id'] == userId);
  psnRank = psnIndex >= 0 ? psnIndex + 1 : null;
  
  // Calculate Xbox rank
  int? xboxRank;
  final xboxList = results[2] as List;
  final xboxIndex = xboxList.indexWhere((row) => row['user_id'] == userId);
  xboxRank = xboxIndex >= 0 ? xboxIndex + 1 : null;
  
  // Calculate Steam rank
  int? steamRank;
  final steamList = results[3] as List;
  final steamIndex = steamList.indexWhere((row) => row['user_id'] == userId);
  steamRank = steamIndex >= 0 ? steamIndex + 1 : null;
  
  return {
    'global': globalRank,
    'psn': psnRank,
    'xbox': xboxRank,
    'steam': steamRank,
  };
});

/// Extension to refresh core data providers after mutations.
extension StatusXPRefresh on WidgetRef {
  void refreshCoreData() {
    invalidate(gamesProvider);
    invalidate(unifiedGamesProvider);
    invalidate(userStatsProvider);
    invalidate(dashboardStatsProvider);
  }
}
