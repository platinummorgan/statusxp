import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/user_stats.dart';
import '../sample_data.dart';

/// Repository interface for managing user statistics persistence.
abstract class UserStatsRepository {
  /// Load user statistics from storage.
  Future<UserStats> loadUserStats();

  /// Save user statistics to storage.
  Future<void> saveUserStats(UserStats stats);
}

/// Local file-based implementation of [UserStatsRepository] using JSON storage.
/// 
/// - Stores user stats in statusxp_user_stats.json in the app documents directory.
/// - On first run (or if file is missing/corrupted), seeds from sample_data.dart.
class LocalFileUserStatsRepository implements UserStatsRepository {
  static const _filename = 'statusxp_user_stats.json';

  /// Get the full path to the user stats JSON file.
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Get the File object for the user stats JSON file.
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_filename');
  }

  @override
  Future<UserStats> loadUserStats() async {
    try {
      final file = await _localFile;

      // First run: seed from sample data if file doesn't exist
      if (!await file.exists()) {
        await saveUserStats(sampleStats);
        return sampleStats;
      }

      // Read and parse JSON
      final contents = await file.readAsString();
      final jsonMap = json.decode(contents) as Map<String, dynamic>;
      final stats = UserStats.fromJson(jsonMap);

      return stats;
    } catch (e) {
      // If JSON is corrupted or any error occurs, fallback to sample data and overwrite
      await saveUserStats(sampleStats);
      return sampleStats;
    }
  }

  @override
  Future<void> saveUserStats(UserStats stats) async {
    final file = await _localFile;
    final jsonMap = stats.toJson();
    final jsonString = json.encode(jsonMap);
    await file.writeAsString(jsonString);
  }
}
