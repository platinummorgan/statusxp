import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:statusxp/domain/game_ref.dart';

@immutable
class AchievementOverview extends Equatable {
  final AchievementRef ref;
  final String name;
  final String gameName;
  final String? gameCoverUrl;
  final String? description;
  final String? iconUrl;
  final double? rarityGlobal;
  final double statusXP;
  final int scoreValue;
  final bool isPlatinum;
  final bool isHidden;
  final DateTime? earnedAt;
  final Map<String, dynamic> metadata;

  const AchievementOverview({
    required this.ref,
    required this.name,
    required this.gameName,
    this.gameCoverUrl,
    this.description,
    this.iconUrl,
    this.rarityGlobal,
    this.statusXP = 0,
    this.scoreValue = 0,
    this.isPlatinum = false,
    this.isHidden = false,
    this.earnedAt,
    this.metadata = const {},
  });

  bool get isEarned => earnedAt != null;

  @override
  List<Object?> get props => [
    ref,
    name,
    gameName,
    gameCoverUrl,
    description,
    iconUrl,
    rarityGlobal,
    statusXP,
    scoreValue,
    isPlatinum,
    isHidden,
    earnedAt,
    metadata,
  ];
}
