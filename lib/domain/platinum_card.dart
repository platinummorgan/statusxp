import 'package:statusxp/domain/game_ref.dart';

class NotableTrophy {
  const NotableTrophy(this.name, this.rarity, this.iconUrl);
  final String name;
  final double rarity;
  final String? iconUrl;
}

class PlatinumCardData {
  const PlatinumCardData({
    required this.ref,
    required this.gameName,
    required this.trophyName,
    required this.playerName,
    required this.number,
    this.coverUrl,
    this.iconUrl,
    this.avatarUrl,
    this.earnedAt,
    this.rarity,
    this.notable = const [],
  });
  final AchievementRef ref;
  final String gameName, trophyName, playerName;
  final int number;
  final String? coverUrl, iconUrl, avatarUrl;
  final DateTime? earnedAt;
  final double? rarity;
  final List<NotableTrophy> notable;
  String get key =>
      '${ref.gameRef.platformId}/${ref.gameRef.platformGameId}/${ref.platformAchievementId}';
  String get platform => ref.gameRef.platform?.label ?? 'PlayStation';
  static double? validRarity(dynamic raw) {
    final value = (raw as num?)?.toDouble();
    return value != null && value.isFinite && value >= 0 && value <= 100
        ? value
        : null;
  }

  factory PlatinumCardData.fromJson(Map<String, dynamic> row) =>
      PlatinumCardData(
        ref: AchievementRef(
          gameRef: GameRef(
            platformId: (row['platform_id'] as num).toInt(),
            platformGameId: row['platform_game_id'] as String,
          ),
          platformAchievementId: row['platform_achievement_id'] as String,
        ),
        gameName: row['game_name'] as String,
        trophyName: row['trophy_name'] as String,
        playerName: row['player_name'] as String,
        number: (row['platinum_number'] as num).toInt(),
        coverUrl: row['cover_url'] as String?,
        iconUrl: row['icon_url'] as String?,
        avatarUrl: row['avatar_url'] as String?,
        earnedAt: DateTime.tryParse(row['earned_at']?.toString() ?? ''),
        rarity: validRarity(row['rarity']),
        notable: [
          for (final t in row['notable'] as List? ?? const [])
            if (validRarity(t['rarity']) != null)
              NotableTrophy(
                t['name'] as String,
                validRarity(t['rarity'])!,
                t['icon_url'] as String?,
              ),
        ],
      );
}

class PlatinumCelebration {
  PlatinumCelebration.fromJson(Map<String, dynamic> row)
    : id = row['id'] as String,
      count = (row['count'] as num).toInt(),
      historical = row['historical'] == true,
      items = (row['items'] as List)
          .map(
            (x) =>
                PlatinumCardData.fromJson(Map<String, dynamic>.from(x as Map)),
          )
          .toList();
  final String id;
  final int count;
  final bool historical;
  final List<PlatinumCardData> items;
  String get title => historical
      ? 'Your platinum collection is here'
      : count == 1
      ? 'A platinum worth celebrating'
      : 'You added $count platinums!';
}
