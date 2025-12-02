import '../domain/game.dart';
import '../domain/user_stats_calculator.dart';
import 'repositories/game_repository.dart';
import 'repositories/user_stats_repository.dart';

/// Service that handles game editing with automatic stats recalculation.
/// 
/// This service ensures that when a game is updated, the user's stats are
/// automatically recalculated to reflect the changes.
class GameEditService {
  GameEditService({
    required GameRepository gameRepository,
    required UserStatsRepository userStatsRepository,
    required UserStatsCalculator statsCalculator,
  })  : _gameRepository = gameRepository,
        _userStatsRepository = userStatsRepository,
        _statsCalculator = statsCalculator;

  final GameRepository _gameRepository;
  final UserStatsRepository _userStatsRepository;
  final UserStatsCalculator _statsCalculator;

  /// Update an existing game and recalculate user stats.
  /// 
  /// Throws an exception if the game with [updatedGame.id] doesn't exist.
  Future<void> updateGame(Game updatedGame) async {
    // 1) Load current games
    final games = await _gameRepository.loadGames();
    
    // 2) Find the game to replace
    final index = games.indexWhere((g) => g.id == updatedGame.id);
    if (index == -1) {
      throw Exception('Game with id ${updatedGame.id} not found');
    }
    
    // 3) Replace the game and save
    games[index] = updatedGame;
    await _gameRepository.saveGames(games);
    
    // 4) Load current user stats to preserve username
    final currentStats = await _userStatsRepository.loadUserStats();
    
    // 5) Recompute stats from updated games list
    final newStats = _statsCalculator.fromGames(
      username: currentStats.username,
      games: games,
    );
    
    // 6) Save the recalculated stats
    await _userStatsRepository.saveUserStats(newStats);
  }
}
