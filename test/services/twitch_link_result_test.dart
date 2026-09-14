import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/twitch_service.dart';

void main() {
  test(
    'a linked account with pending verification remains a successful link',
    () async {
      final client = SupabaseClient(
        'https://example.invalid',
        'fixture',
        httpClient: MockClient(
          (request) async => http.Response(
            '{"success":true,"twitchUserId":"20","isSubscribed":null,"subscriptionCheckPending":true}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      final result = await TwitchService(
        client,
      ).linkAccount('fixture-code', 'https://statusxp.com/callback');
      expect(result.success, isTrue);
      expect(result.subscriptionCheckPending, isTrue);
      expect(result.isSubscribed, isFalse);
    },
  );
}
