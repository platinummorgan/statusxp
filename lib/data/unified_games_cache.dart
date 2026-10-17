import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A private account's last successful library response, never a public profile.
class UnifiedGamesCache {
  UnifiedGamesCache({this.namespace = 'unified_games_v1'});
  final String namespace;
  String _key(String userId) => '${namespace}_$userId';

  Future<List<dynamic>?> read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key(userId));
      return value == null ? null : jsonDecode(value) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String userId, List<dynamic> games) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(userId), jsonEncode(games));
    } catch (_) {
      // Displaying a successful response must not depend on local storage.
    }
  }
}
