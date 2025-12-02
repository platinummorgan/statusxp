import '../domain/game.dart';
import '../domain/user_stats_calculator.dart';
import 'repositories/supabase_game_repository.dart';
import 'repositories/supabase_user_stats_repository.dart';

/// Service that handles game editing with automatic stats recalculation (Supabase version).
/// 
/// This service ensures that when a game is updated in Supabase, the user's stats are
/// automatically recalculated to reflect the changes.
class SupabaseGameEditService {
  SupabaseGameEditService({
    required SupabaseGameRepository gameRepository,
    required SupabaseUserStatsRepository userStatsRepository,
    required UserStatsCalculator statsCalculator,
    required String userId,
  })  : _gameRepository = gameRepository,
        _userStatsRepository = userStatsRepository,
        _statsCalculator = statsCalculator,
        _userId = userId;

  final SupabaseGameRepository _gameRepository;
  final SupabaseUserStatsRepository _userStatsRepository;
  final UserStatsCalculator _statsCalculator;
  final String _userId;

  /// Update an existing game and recalculate user stats.
  /// 
  /// Throws an exception if the game update fails.
  Future<void> updateGame(Game updatedGame) async {
    // 1) Update the game in Supabase
    await _gameRepository.updateGame(updatedGame);
    
    // 2) Load all games for the user to recalculate stats
    final games = await _gameRepository.getGamesForUser(_userId);
    
    // 3) Load current user stats to preserve username
    final currentStats = await _userStatsRepository.getUserStats(_userId);
    
    // 4) Recompute stats from updated games list
    final newStats = _statsCalculator.fromGames(
      username: currentStats.username,
      games: games,
    );
    
    // 5) Save the recalculated stats to Supabase
    await _userStatsRepository.updateUserStats(_userId, newStats);
  }

  /// Add a new game for the user.
  Future<void> addGame(Game game) async {
    // 1) Insert the game
    await _gameRepository.insertGame(_userId, game);
    
    // 2) Reload games and recalculate stats
    final games = await _gameRepository.getGamesForUser(_userId);
    final currentStats = await _userStatsRepository.getUserStats(_userId);
    final newStats = _statsCalculator.fromGames(
      username: currentStats.username,
      games: games,
    );
    
    // 3) Update stats
    await _userStatsRepository.updateUserStats(_userId, newStats);
  }

  /// Delete a game and recalculate stats.
  Future<void> deleteGame(int gameId) async {
    // 1) Delete the game
    await _gameRepository.deleteGame(gameId);
    
    // 2) Reload games and recalculate stats
    final games = await _gameRepository.getGamesForUser(_userId);
    final currentStats = await _userStatsRepository.getUserStats(_userId);
    final newStats = _statsCalculator.fromGames(
      username: currentStats.username,
      games: games,
    );
    
    // 3) Update stats
    await _userStatsRepository.updateUserStats(_userId, newStats);
  }
}
