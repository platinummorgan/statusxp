import 'package:statusxp/domain/game.dart';
import 'package:statusxp/domain/user_stats.dart';

/// Sample games data for v0.1 prototype demonstration.
/// 
/// This list contains realistic game entries across multiple platforms
/// with varied completion percentages and trophy counts.
final List<Game> sampleGames = [
  const Game(
    id: '1',
    name: 'Elden Ring',
    platform: 'PS5',
    totalTrophies: 42,
    earnedTrophies: 42,
    hasPlatinum: true,
    rarityPercent: 5.8,
    cover: 'placeholder.png',
  ),
  const Game(
    id: '2',
    name: 'God of War Ragnarök',
    platform: 'PS5',
    totalTrophies: 36,
    earnedTrophies: 36,
    hasPlatinum: true,
    rarityPercent: 12.4,
    cover: 'placeholder.png',
  ),
  const Game(
    id: '3',
    name: 'Returnal',
    platform: 'PS5',
    totalTrophies: 31,
    earnedTrophies: 25,
    hasPlatinum: false,
    rarityPercent: 2.1,
    cover: 'placeholder.png',
  ),
  const Game(
    id: '4',
    name: 'Horizon Forbidden West',
    platform: 'PS5',
    totalTrophies: 59,
    earnedTrophies: 59,
    hasPlatinum: true,
    rarityPercent: 18.3,
    cover: 'placeholder.png',
  ),
  const Game(
    id: '5',
    name: 'Bloodborne',
    platform: 'PS4',
    totalTrophies: 41,
    earnedTrophies: 41,
    hasPlatinum: true,
    rarityPercent: 7.2,
    cover: 'placeholder.png',
  ),
  const Game(
    id: '6',
    name: 'The Last of Us Part II',
    platform: 'PS4',
    totalTrophies: 28,
    earnedTrophies: 28,
    hasPlatinum: true,
    rarityPercent: 21.5,
    cover: 'placeholder.png',
  ),
  const Game(
    id: '7',
    name: 'Ghost of Tsushima',
    platform: 'PS4',
    totalTrophies: 51,
    earnedTrophies: 48,
    hasPlatinum: false,
    rarityPercent: 15.7,
    cover: 'placeholder.png',
  ),
  const Game(
    id: '8',
    name: 'Hades',
    platform: 'PS5',
    totalTrophies: 49,
    earnedTrophies: 32,
    hasPlatinum: false,
    rarityPercent: 8.9,
    cover: 'placeholder.png',
  ),
  const Game(
    id: '9',
    name: 'Sekiro: Shadows Die Twice',
    platform: 'PS4',
    totalTrophies: 34,
    earnedTrophies: 34,
    hasPlatinum: true,
    rarityPercent: 3.4,
    cover: 'placeholder.png',
  ),
  const Game(
    id: '10',
    name: 'Resident Evil Village',
    platform: 'PS5',
    totalTrophies: 47,
    earnedTrophies: 39,
    hasPlatinum: false,
    rarityPercent: 11.2,
    cover: 'placeholder.png',
  ),
  const Game(
    id: '11',
    name: 'Halo Infinite',
    platform: 'Xbox',
    totalTrophies: 119,
    earnedTrophies: 95,
    hasPlatinum: false,
    rarityPercent: 6.5,
    cover: 'placeholder.png',
  ),
  const Game(
    id: '12',
    name: 'Celeste',
    platform: 'PS4',
    totalTrophies: 32,
    earnedTrophies: 30,
    hasPlatinum: false,
    rarityPercent: 4.7,
    cover: 'placeholder.png',
  ),
];

/// Sample user statistics for v0.1 prototype demonstration.
/// 
/// These stats are calculated based on the sample games above
/// and represent a realistic high-level gamer profile.
const UserStats sampleStats = UserStats(
  username: 'TrophyHunter_92',
  totalPlatinums: 7,
  totalGamesTracked: 12,
  totalTrophies: 509,
  hardestPlatGame: 'Sekiro: Shadows Die Twice',
  rarestTrophyName: 'Return to the Dream',
  rarestTrophyRarity: 2.1,
);
