import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/psn_service.dart';
import 'package:statusxp/data/xbox_service.dart';
import 'package:statusxp/services/auto_sync_service.dart';

class CountXbox extends XboxService {
  CountXbox(super.client);
  int starts = 0;
  @override
  Future<XboxSyncStartResult> startSync({
    String syncType = 'full',
    bool forceResync = false,
    bool isAutoSync = false,
  }) async {
    starts++;
    throw XboxRateLimitException('Already refreshed');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final fail in [false, true]) {
    test(
      'automatic sync ${fail ? 'waits when security checks fail' : 'skips pending PSN but still attempts Xbox'}',
      () async {
        var psnStarts = 0;
        var checks = 0;
        final client = SupabaseClient(
          'https://test.invalid',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient((request) async {
            Object body;
            var status = 200;
            if (request.url.path.endsWith('/activate_security_reconnect')) {
              checks++;
              status = fail ? 503 : 200;
              body = fail
                  ? {'message': 'Offline', 'code': 'offline'}
                  : [
                      {'platform': 'psn'},
                    ];
            } else if (request.url.path.endsWith('/profiles')) {
              body = {
                'psn_account_id': 'psn',
                'xbox_xuid': 'xbox',
                'steam_id': null,
                'last_psn_sync_at': null,
                'last_xbox_sync_at': null,
                'last_steam_sync_at': null,
                'psn_sync_status': 'success',
                'xbox_sync_status': 'success',
                'steam_sync_status': 'success',
              };
            } else {
              psnStarts++;
              body = {'error': 'Unexpected sync'};
              status = 400;
            }
            return http.Response(
              jsonEncode(body),
              status,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        addTearDown(client.dispose);
        final expires =
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000;
        final payload = base64Url
            .encode(utf8.encode(jsonEncode({'sub': 'owner', 'exp': expires})))
            .replaceAll('=', '');
        await client.auth.recoverSession(
          jsonEncode({
            'access_token': 'e30.$payload.signature',
            'refresh_token': 'refresh',
            'expires_at': expires,
            'expires_in': 3600,
            'token_type': 'bearer',
            'user': {
              'id': 'owner',
              'aud': 'authenticated',
              'app_metadata': {},
              'user_metadata': {},
              'created_at': '2026-10-18T12:00:00Z',
            },
          }),
        );
        final xbox = CountXbox(client);
        final service = AutoSyncService(client, PSNService(client), xbox);
        if (fail) {
          await expectLater(
            service.checkAndSync(),
            throwsA(isA<PostgrestException>()),
          );
        } else {
          await service.checkAndSync();
        }
        expect(checks, 1);
        expect(psnStarts, 0);
        expect(xbox.starts, fail ? 0 : 1);
      },
    );
  }
}
