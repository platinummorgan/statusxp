import 'package:statusxp/domain/game.dart';
import 'package:statusxp/domain/user_stats.dart';

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
  /// 
  /// Note: Trophy tier breakdown (bronze, silver, gold, platinum) is estimated
  /// based on typical trophy distributions since Game model doesn't track
  /// individual trophy tiers. For accurate breakdown, use Supabase repository
  /// which queries the trophies table directly.
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
    
    // Estimate trophy breakdown based on typical distributions
    // In a real app, this would come from individual trophy records
    // Typical distribution: ~60% bronze, ~30% silver, ~8% gold, ~2% platinum
    final platinumCount = totalPlatinums;
    final goldCount = (totalTrophies * 0.08).round();
    final silverCount = (totalTrophies * 0.30).round();
    final bronzeCount = totalTrophies - platinumCount - goldCount - silverCount;
    
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
      avatarUrl: null, // Avatar is fetched separately from profiles table
      isPsPlus: false, // PS Plus status is fetched separately from profiles table
      totalPlatinums: totalPlatinums,
      totalGamesTracked: totalGamesTracked,
      totalTrophies: totalTrophies,
      bronzeTrophies: bronzeCount,
      silverTrophies: silverCount,
      goldTrophies: goldCount,
      platinumTrophies: platinumCount,
      hardestPlatGame: hardestPlatGame,
      rarestTrophyName: rarestTrophyName,
      rarestTrophyRarity: rarestTrophyRarity,
    );
  }
}
