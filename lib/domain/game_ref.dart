import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

@immutable
class PlatformDefinition extends Equatable {
  final int id;
  final String code;
  final String label;

  const PlatformDefinition({
    required this.id,
    required this.code,
    required this.label,
  });

  @override
  List<Object> get props => [id, code, label];
}

abstract final class PlatformRegistry {
  static const List<PlatformDefinition> platforms = [
    PlatformDefinition(id: 1, code: 'ps5', label: 'PlayStation 5'),
    PlatformDefinition(id: 2, code: 'ps4', label: 'PlayStation 4'),
    PlatformDefinition(id: 4, code: 'steam', label: 'Steam'),
    PlatformDefinition(id: 5, code: 'ps3', label: 'PlayStation 3'),
    PlatformDefinition(id: 9, code: 'psvita', label: 'PlayStation Vita'),
    PlatformDefinition(id: 10, code: 'xbox360', label: 'Xbox 360'),
    PlatformDefinition(id: 11, code: 'xboxone', label: 'Xbox One'),
    PlatformDefinition(id: 12, code: 'xboxseries', label: 'Xbox Series X|S'),
  ];

  static PlatformDefinition? fromId(int id) {
    for (final platform in platforms) {
      if (platform.id == id) return platform;
    }
    return null;
  }

  static PlatformDefinition? fromCode(String code) {
    final normalized = code.trim().toLowerCase();
    for (final platform in platforms) {
      if (platform.code == normalized) return platform;
    }
    return null;
  }
}

@immutable
class GameRef extends Equatable {
  final int platformId;
  final String platformGameId;

  const GameRef({required this.platformId, required this.platformGameId});

  PlatformDefinition? get platform => PlatformRegistry.fromId(platformId);

  String get location {
    final platformCode = platform?.code;
    if (platformCode == null) {
      throw StateError('Unknown platform ID: $platformId');
    }
    return '/games/$platformCode/${Uri.encodeComponent(platformGameId)}';
  }

  static GameRef? fromRoute({
    required String platformCode,
    required String encodedGameId,
  }) {
    final platform = PlatformRegistry.fromCode(platformCode);
    if (platform == null) return null;
    late final String gameId;
    try {
      gameId = Uri.decodeComponent(encodedGameId).trim();
    } on FormatException {
      return null;
    }
    if (gameId.isEmpty) return null;
    return GameRef(platformId: platform.id, platformGameId: gameId);
  }

  @override
  List<Object> get props => [platformId, platformGameId];
}
