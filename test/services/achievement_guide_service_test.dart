import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/services/achievement_guide_service.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'reopening a guide preserves its persisted retry after release',
    () async {
      final ids = <String>[];
      final client = MockClient((request) async {
        ids.add(jsonDecode(request.body)['requestId'] as String);
        if (ids.length == 1) {
          return http.Response('{"code":"released","error":"Released"}', 422);
        }
        if (ids.length == 2) throw http.ClientException('Lost response');
        return http.Response('{"guide":"Recovered"}', 200);
      });
      Future<List<String>> reopen() =>
          AchievementGuideService(
                client: client,
                accessToken: () => 'token',
                userId: () => 'alice',
              )
              .generateGuide(
                gameTitle: 'Game',
                achievementName: 'Win',
                achievementDescription: '',
              )
              .toList();
      await expectLater(reopen(), throwsException);
      await expectLater(reopen(), throwsA(isA<http.ClientException>()));
      expect(await reopen(), ['Recovered']);
      expect(ids[0], isNot(ids[1]));
      expect(ids[1], ids[2]);
    },
  );
  test(
    'uncertain retries and successful replay retain ID; account changes isolate ID',
    () async {
      final ids = <String>[];
      var user = 'alice';
      final service = AchievementGuideService(
        userId: () => user,
        accessToken: () => 'token',
        client: MockClient((request) async {
          ids.add(jsonDecode(request.body)['requestId'] as String);
          if (ids.length == 1) throw http.ClientException('Connection lost');
          return http.Response('{"guide":"Saved guide"}', 200);
        }),
      );
      Future<List<String>> generate() => service
          .generateGuide(
            gameTitle: 'Game',
            achievementName: 'Win',
            achievementDescription: '',
          )
          .toList();
      await expectLater(generate(), throwsA(isA<http.ClientException>()));
      expect(await generate(), ['Saved guide']);
      expect(await generate(), ['Saved guide']);
      expect(ids.toSet().length, 1);
      user = 'bob';
      await generate();
      expect(ids.last, isNot(ids.first));
    },
  );
  for (final status in [422, 429, 503]) {
    test('confirmed release at $status permits a fresh attempt', () async {
      final ids = <String>[];
      final service = AchievementGuideService(
        userId: () => 'alice',
        accessToken: () => 'token',
        client: MockClient((request) async {
          ids.add(jsonDecode(request.body)['requestId'] as String);
          return ids.length == 1
              ? http.Response('{"error":"Released","code":"released"}', status)
              : http.Response('{"guide":"Guide"}', 200);
        }),
      );
      Future<List<String>> generate() => service
          .generateGuide(
            gameTitle: 'Game',
            achievementName: 'Win',
            achievementDescription: '',
          )
          .toList();
      await expectLater(generate(), throwsException);
      expect(await generate(), ['Guide']);
      expect(ids.last, isNot(ids.first));
    });
  }
  test('no session cannot call generation', () async {
    final service = AchievementGuideService(
      userId: () => null,
      accessToken: () => null,
      client: MockClient((_) async => throw StateError('Must not call')),
    );
    await expectLater(
      service
          .generateGuide(
            gameTitle: 'G',
            achievementName: 'A',
            achievementDescription: '',
          )
          .toList(),
      throwsException,
    );
  });
}
