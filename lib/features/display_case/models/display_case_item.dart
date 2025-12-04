import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

/// Type of display item in the trophy case
enum DisplayItemType {
  /// PSN/Xbox/Steam trophy icon
  trophyIcon,
  
  /// Game cover art displayed as framed picture
  gameCover,
  
  /// Future: Custom 3D figurine
  figurine,
  
  /// Future: Custom uploaded image
  custom,
}

/// A single item displayed in the trophy case
@immutable
class DisplayCaseItem extends Equatable {
  /// Unique ID for this display item
  final String id;
  
  /// User who owns this display
  final String userId;
  
  /// Trophy ID from database
  final int trophyId;
  
  /// How this trophy is displayed
  final DisplayItemType displayType;
  
  /// Which shelf (0-indexed from top)
  final int shelfNumber;
  
  /// Position within shelf (0-indexed from left)
  final int positionInShelf;
  
  /// Trophy details for rendering
  final String trophyName;
  final String gameName;
  final String tier; // bronze, silver, gold, platinum
  final double? rarity;
  final String? iconUrl;
  final String? gameImageUrl;

  const DisplayCaseItem({
    required this.id,
    required this.userId,
    required this.trophyId,
    required this.displayType,
    required this.shelfNumber,
    required this.positionInShelf,
    required this.trophyName,
    required this.gameName,
    required this.tier,
    this.rarity,
    this.iconUrl,
    this.gameImageUrl,
  });

  /// Create a copy with updated position
  DisplayCaseItem copyWith({
    String? id,
    String? userId,
    int? trophyId,
    DisplayItemType? displayType,
    int? shelfNumber,
    int? positionInShelf,
    String? trophyName,
    String? gameName,
    String? tier,
    double? rarity,
    String? iconUrl,
    String? gameImageUrl,
  }) {
    return DisplayCaseItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      trophyId: trophyId ?? this.trophyId,
      displayType: displayType ?? this.displayType,
      shelfNumber: shelfNumber ?? this.shelfNumber,
      positionInShelf: positionInShelf ?? this.positionInShelf,
      trophyName: trophyName ?? this.trophyName,
      gameName: gameName ?? this.gameName,
      tier: tier ?? this.tier,
      rarity: rarity ?? this.rarity,
      iconUrl: iconUrl ?? this.iconUrl,
      gameImageUrl: gameImageUrl ?? this.gameImageUrl,
    );
  }

  /// Convert to JSON for database storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'trophy_id': trophyId,
      'display_type': displayType.name,
      'shelf_number': shelfNumber,
      'position_in_shelf': positionInShelf,
    };
  }

  /// Create from database row
  factory DisplayCaseItem.fromMap(Map<String, dynamic> map) {
    return DisplayCaseItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      trophyId: map['trophy_id'] as int,
      displayType: DisplayItemType.values.firstWhere(
        (e) => e.name == map['display_type'],
        orElse: () => DisplayItemType.trophyIcon,
      ),
      shelfNumber: map['shelf_number'] as int,
      positionInShelf: map['position_in_shelf'] as int,
      trophyName: map['trophy_name'] as String,
      gameName: map['game_name'] as String,
      tier: map['tier'] as String,
      rarity: (map['rarity'] as num?)?.toDouble(),
      iconUrl: map['icon_url'] as String?,
      gameImageUrl: map['game_image_url'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        trophyId,
        displayType,
        shelfNumber,
        positionInShelf,
        trophyName,
        gameName,
        tier,
        rarity,
        iconUrl,
        gameImageUrl,
      ];
}

/// Configuration for the display case layout
@immutable
class DisplayCaseConfig extends Equatable {
  /// Number of items per shelf
  final int itemsPerShelf;
  
  /// Number of shelves
  final int numberOfShelves;
  
  /// Height of each shelf in pixels
  final double shelfHeight;
  
  /// Spacing between shelves
  final double shelfSpacing;

  const DisplayCaseConfig({
    this.itemsPerShelf = 3,
    this.numberOfShelves = 10,
    this.shelfHeight = 140,
    this.shelfSpacing = 24,
  });

  @override
  List<Object?> get props => [itemsPerShelf, numberOfShelves, shelfHeight, shelfSpacing];
}
