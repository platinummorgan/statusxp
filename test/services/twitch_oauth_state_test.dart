import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/services/twitch_oauth_state.dart';

void main() {
  late Map<String, String> storage;
  late DateTime now;
  late TwitchOAuthState flow;
  setUp(() {
    storage = {};
    now = DateTime.utc(2026, 9, 11);
    flow = TwitchOAuthState(
      read: (key) => storage[key],
      write: (key, value) => storage[key] = value,
      remove: storage.remove,
      now: () => now,
    );
  });
  Uri callback(String state, {String code = 'provider-code'}) => Uri.https(
    'statusxp.com',
    '/twitch-callback',
    {'state': state, 'code': code},
  );

  test('fresh random state permits a callback exactly once', () {
    final state = flow.begin('user:session');
    expect(state, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(
      flow.consumeCallback(callback(state), 'user:session'),
      'provider-code',
    );
    expect(storage, isEmpty);
    expect(
      () => flow.consumeCallback(callback(state), 'user:session'),
      throwsStateError,
    );
    expect(flow.begin('user:session'), isNot(state));
  });

  for (final mode in [
    'missing',
    'mismatch',
    'expired',
    'future',
    'other user',
    'new session',
    'signed out',
    'duplicate state',
    'missing code',
    'duplicate code',
    'corrupt',
  ]) {
    test('$mode callback is rejected and consumed', () {
      final state = flow.begin('user:session');
      var uri = callback(state);
      String? binding = 'user:session';
      switch (mode) {
        case 'missing':
          uri = Uri.parse('https://statusxp.com/twitch-callback?code=code');
        case 'mismatch':
          uri = callback('attacker-state');
        case 'expired':
          now = now.add(TwitchOAuthState.lifetime);
        case 'future':
          now = now.subtract(const Duration(seconds: 1));
        case 'other user':
          binding = 'other:session';
        case 'new session':
          binding = 'user:new-session';
        case 'signed out':
          binding = null;
        case 'duplicate state':
          uri = Uri.parse('${uri.toString()}&state=$state');
        case 'missing code':
          uri = callback(state, code: '');
        case 'duplicate code':
          uri = Uri.parse('${uri.toString()}&code=other');
        case 'corrupt':
          storage[TwitchOAuthState.storageKey] = '{invalid';
      }
      expect(() => flow.consumeCallback(uri, binding), throwsStateError);
      expect(storage, isEmpty);
      expect(
        () => flow.consumeCallback(callback(state), 'user:session'),
        throwsStateError,
      );
    });
  }

  test('provider rejection consumes state without returning a code', () {
    final state = flow.begin('user:session');
    final uri = Uri.https('statusxp.com', '/twitch-callback', {
      'state': state,
      'error': 'access_denied',
      'code': 'must-not-exchange',
    });
    expect(() => flow.consumeCallback(uri, 'user:session'), throwsStateError);
    expect(storage, isEmpty);
  });

  test('starting again invalidates the previous attempt', () {
    final old = flow.begin('user:session');
    final fresh = flow.begin('user:session');
    expect(fresh, isNot(old));
    expect(
      () => flow.consumeCallback(callback(old), 'user:session'),
      throwsStateError,
    );
  });

  test('missing login and unavailable storage cannot start a redirect', () {
    expect(() => flow.begin(null), throwsStateError);
    final blocked = TwitchOAuthState(
      read: (_) => null,
      write: (_, _) => throw StateError('blocked'),
      remove: (_) {},
    );
    expect(() => blocked.begin('user:session'), throwsStateError);
  });

  test(
    'session binding survives refresh and changes on login/account changes',
    () {
      String token(String session, int expiry) =>
          'header.${base64Url.encode(utf8.encode(jsonEncode({'session_id': session, 'exp': expiry})))}.signature';
      final binding = TwitchOAuthState.sessionBinding(
        'user',
        token('session', 1),
      );
      expect(binding, isNotNull);
      expect(
        TwitchOAuthState.sessionBinding('user', token('session', 2)),
        binding,
      );
      expect(
        TwitchOAuthState.sessionBinding('other', token('session', 2)),
        isNot(binding),
      );
      expect(
        TwitchOAuthState.sessionBinding('user', token('new', 2)),
        isNot(binding),
      );
      expect(
        TwitchOAuthState.sessionBinding(null, token('session', 2)),
        isNull,
      );
      expect(TwitchOAuthState.sessionBinding('user', 'malformed'), isNull);
    },
  );
}
