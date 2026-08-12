import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:statusxp/domain/game_ref.dart';

@immutable
class GameOverview extends Equatable {
  final GameRef ref;
  final String name;
  final String? coverUrl;
  final String? iconUrl;
  final Map<String, dynamic> metadata;
  final int achievementsEarned;
  final int achievementsTotal;
  final double completionPercentage;
  final int currentScore;
  final int totalScore;
  final DateTime? lastPlayedAt;
  final bool isOwned;

  const GameOverview({
    required this.ref,
    required this.name,
    this.coverUrl,
    this.iconUrl,
    this.metadata = const {},
    this.achievementsEarned = 0,
    this.achievementsTotal = 0,
    this.completionPercentage = 0,
    this.currentScore = 0,
    this.totalScore = 0,
    this.lastPlayedAt,
    this.isOwned = false,
  });

  String? get description => metadata['description']?.toString();
  String? get developer => metadata['developer']?.toString();
  String? get publisher => metadata['publisher']?.toString();

  @override
  List<Object?> get props => [
    ref,
    name,
    coverUrl,
    iconUrl,
    metadata,
    achievementsEarned,
    achievementsTotal,
    completionPercentage,
    currentScore,
    totalScore,
    lastPlayedAt,
    isOwned,
  ];
}
