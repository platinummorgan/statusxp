import 'dart:convert';
import 'package:statusxp/ui/widgets/premium_access_issue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/services/premium_access.dart';

void main() {
  Future<SupabaseClient> clientFor(
    List<String> calls,
    Object rpcBody,
    int status,
  ) async {
    final client = SupabaseClient(
      'https://test.invalid',
      'test',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        calls.add(request.url.path);
        final rpc = request.url.path.contains('/rpc/');
        return http.Response(
          jsonEncode(
            rpc
                ? rpcBody
                : {
                    'is_premium': true,
                    'premium_expires_at': null,
                    'premium_source': 'legacy',
                    'premium_since': null,
                  },
          ),
          rpc ? status : 200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    await client.auth.recoverSession(
      jsonEncode({
        'access_token': 'fixture',
        'refresh_token': 'fixture',
        'token_type': 'bearer',
        'expires_at':
            DateTime.now()
                .add(const Duration(hours: 1))
                .millisecondsSinceEpoch ~/
            1000,
        'user': {
          'id': 'owner',
          'app_metadata': {},
          'user_metadata': {},
          'aud': 'authenticated',
          'created_at': '2026-09-14T00:00:00Z',
        },
      }),
    );
    return client;
  }

  test('missing new RPC uses legacy entitlement during rollout', () async {
    final calls = <String>[];
    final client = await clientFor(calls, {
      'code': 'PGRST202',
      'message': 'Missing function',
    }, 404);
    expect(hasActivePremium(await readPremiumEntitlement(client)), isTrue);
    expect(calls.last, endsWith('/user_premium_status'));
  });

  test('explicit denial cannot fall back to a legacy premium flag', () async {
    final calls = <String>[];
    final client = await clientFor(calls, {'is_premium': false}, 200);
    expect(hasActivePremium(await readPremiumEntitlement(client)), isFalse);
    expect(
      calls.where((path) => path.endsWith('/user_premium_status')),
      isEmpty,
    );
  });

  test('permission and server errors do not fall back', () async {
    for (final code in ['42501', 'XX000']) {
      final calls = <String>[];
      final client = await clientFor(calls, {
        'code': code,
        'message': 'Unavailable',
      }, 500);
      await expectLater(
        readPremiumEntitlement(client),
        throwsA(isA<PostgrestException>()),
      );
      expect(
        calls.where((path) => path.endsWith('/user_premium_status')),
        isEmpty,
      );
    }
  });
  test(
    'premium diagnostics distinguish active, expired and failed checks',
    () async {
      final active = await clientFor([], {
        'is_premium': true,
        'premium_expires_at': null,
      }, 200);
      expect(await premiumAccessIssue(active), isNull);
      final expired = await clientFor([], {
        'is_premium': true,
        'premium_expires_at': '2020-01-01T00:00:00Z',
      }, 200);
      expect(await premiumAccessIssue(expired), contains('expired'));
      final failed = await clientFor([], {
        'code': '57014',
        'message': 'timeout',
      }, 500);
      expect(await premiumAccessIssue(failed), contains('57014'));
      expect(
        await premiumAccessIssue(failed),
        isNot(contains('not currently premium')),
      );
    },
  );
}
