import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Represents a trophy/achievement from a game
@immutable
class Trophy extends Equatable {
  /// Unique identifier
  final String id;
  
  /// Trophy name
  final String name;
  
  /// Trophy description
  final String? description;
  
  /// Trophy tier (bronze, silver, gold, platinum)
  final String tier;
  
  /// Icon URL
  final String? iconUrl;
  
  /// Global rarity percentage (0.0 to 100.0)
  final double? rarityGlobal;
  
  /// Whether trophy is hidden/secret
  final bool hidden;
  
  /// Whether user has earned this trophy
  final bool earned;
  
  /// When trophy was earned
  final DateTime? earnedAt;
  
  const Trophy({
    required this.id,
    required this.name,
    this.description,
    required this.tier,
    this.iconUrl,
    this.rarityGlobal,
    this.hidden = false,
    this.earned = false,
    this.earnedAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        tier,
        iconUrl,
        rarityGlobal,
        hidden,
        earned,
        earnedAt,
      ];
}
