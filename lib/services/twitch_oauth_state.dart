import 'dart:convert';
import 'dart:math';

/// Tab-local CSRF protection. This does not replace server authentication.
class TwitchOAuthState {
  TwitchOAuthState({
    required this.read,
    required this.write,
    required this.remove,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  static const storageKey = 'statusxp.twitch.oauth.pending.v1';
  static const lifetime = Duration(minutes: 10);
  final String? Function(String) read;
  final void Function(String, String) write;
  final void Function(String) remove;
  final DateTime Function() now;

  // session_id survives token refresh but changes on a new sign-in. Decoding
  // here only correlates local sessions; the server still verifies the JWT.
  static String? sessionBinding(String? userId, String? accessToken) {
    if (userId == null || accessToken == null) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(
          base64Url.decode(base64Url.normalize(accessToken.split('.')[1])),
        ),
      );
      final sessionId = payload['session_id'];
      if (sessionId is! String || sessionId.isEmpty) return null;
      return '$userId:$sessionId';
    } catch (_) {
      return null;
    }
  }

  String begin(String? binding) {
    remove(storageKey);
    if (binding == null) {
      throw StateError('Sign in again before connecting Twitch.');
    }
    final random = Random.secure();
    final state = base64Url
        .encode(List.generate(32, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    write(
      storageKey,
      jsonEncode({
        'state': state,
        'binding': binding,
        'issuedAt': now().millisecondsSinceEpoch,
      }),
    );
    return state;
  }

  /// Consumes even rejected callbacks, so retries require a fresh authorization.
  String consumeCallback(Uri uri, String? binding) {
    final saved = read(storageKey);
    remove(storageKey);
    const invalid =
        'Twitch authorization could not be verified. Please connect again.';
    try {
      final states = uri.queryParametersAll['state'];
      if (saved == null || binding == null || states?.length != 1) {
        throw const FormatException();
      }
      final pending = jsonDecode(saved);
      final issuedAt = pending['issuedAt'];
      if (issuedAt is! int ||
          pending['binding'] != binding ||
          pending['state'] != states!.single ||
          states.single.isEmpty) {
        throw const FormatException();
      }
      final age = now().millisecondsSinceEpoch - issuedAt;
      if (age < 0 || age >= lifetime.inMilliseconds) {
        throw const FormatException();
      }
    } catch (_) {
      throw StateError(invalid);
    }
    if (uri.queryParameters.containsKey('error')) {
      throw StateError('Twitch authorization was declined. You can try again.');
    }
    final codes = uri.queryParametersAll['code'];
    if (codes?.length != 1 || codes!.single.trim().isEmpty) {
      throw StateError(invalid);
    }
    return codes.single;
  }
}
