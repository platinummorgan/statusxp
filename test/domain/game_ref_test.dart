import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/domain/game_ref.dart';

void main() {
  group('PlatformRegistry', () {
    test('contains every approved platform mapping', () {
      expect(
        PlatformRegistry.platforms.map(
          (platform) => (platform.id, platform.code),
        ),
        containsAll(const [
          (1, 'ps5'),
          (2, 'ps4'),
          (4, 'steam'),
          (5, 'ps3'),
          (9, 'psvita'),
          (10, 'xbox360'),
          (11, 'xboxone'),
          (12, 'xboxseries'),
        ]),
      );
    });

    test('code lookup is case insensitive', () {
      expect(PlatformRegistry.fromCode('PS5')?.id, 1);
    });

    test('unknown codes and IDs return null', () {
      expect(PlatformRegistry.fromCode('switch'), isNull);
      expect(PlatformRegistry.fromId(999), isNull);
    });
  });

  group('GameRef', () {
    test('builds a canonical URL and encodes the platform game ID', () {
      const gameRef = GameRef(platformId: 4, platformGameId: 'app/123 test');
      expect(gameRef.location, '/games/steam/app%2F123%20test');
    });

    test('round trips through route parameters', () {
      final gameRef = GameRef.fromRoute(
        platformCode: 'xboxseries',
        encodedGameId: 'game%2F42',
      );
      expect(gameRef, const GameRef(platformId: 12, platformGameId: 'game/42'));
    });

    test('rejects invalid route parameters', () {
      expect(
        GameRef.fromRoute(platformCode: 'switch', encodedGameId: '123'),
        isNull,
      );
      expect(
        GameRef.fromRoute(platformCode: 'ps5', encodedGameId: '%20'),
        isNull,
      );
      expect(
        GameRef.fromRoute(platformCode: 'ps5', encodedGameId: '%ZZ'),
        isNull,
      );
    });
  });

  group('AchievementRef', () {
    test('round trips canonical achievement identifiers', () {
      const item = AchievementRef(
        gameRef: GameRef(platformId: 1, platformGameId: 'NPWR/123'),
        platformAchievementId: 'trophy 42',
      );
      expect(item.location, '/games/ps5/NPWR%2F123/achievements/trophy%2042');
      expect(
        AchievementRef.fromRoute(
          platformCode: 'ps5',
          encodedGameId: 'NPWR%2F123',
          encodedAchievementId: 'trophy%2042',
        ),
        item,
      );
    });

    test('rejects malformed achievement identifiers', () {
      expect(
        AchievementRef.fromRoute(
          platformCode: 'ps5',
          encodedGameId: 'NPWR123',
          encodedAchievementId: '%ZZ',
        ),
        isNull,
      );
    });
  });
}
