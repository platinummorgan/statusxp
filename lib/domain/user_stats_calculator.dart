import 'game.dart';
import 'user_stats.dart';

/// Pure-domain helper that recomputes UserStats from a list of Games.
/// 
/// This calculator is stateless and side-effect-free, making it easy to test
/// and use in different contexts (editing, bulk updates, etc.).
class UserStatsCalculator {
  const UserStatsCalculator();

  /// Recompute UserStats from the current list of games.
  /// 
  /// Preserves the provided [username] while calculating all trophy stats
  /// from the games list.
  UserStats fromGames({
    required String username,
    required List<Game> games,
  }) {
    final totalGamesTracked = games.length;
    
    // Count platinum games
    final platinumGames = games.where((g) => g.hasPlatinum).toList();
    final totalPlatinums = platinumGames.length;
    
    // Sum all earned trophies
    final totalTrophies = games.fold<int>(
      0,
      (sum, game) => sum + game.earnedTrophies,
    );
    
    // Find the hardest platinum (lowest rarity %)
    String hardestPlatGame = 'N/A';
    String rarestTrophyName = 'N/A';
    double rarestTrophyRarity = 0.0;
    
    if (platinumGames.isNotEmpty) {
      // Find platinum game with lowest rarity percent
      final hardest = platinumGames.reduce((a, b) {
        return a.rarityPercent < b.rarityPercent ? a : b;
      });
      
      hardestPlatGame = hardest.name;
      rarestTrophyName = hardest.name;
      rarestTrophyRarity = hardest.rarityPercent;
    }
    
    return UserStats(
      username: username,
      totalPlatinums: totalPlatinums,
      totalGamesTracked: totalGamesTracked,
      totalTrophies: totalTrophies,
      hardestPlatGame: hardestPlatGame,
      rarestTrophyName: rarestTrophyName,
      rarestTrophyRarity: rarestTrophyRarity,
    );
  }
}
