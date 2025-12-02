import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/game.dart';
import '../sample_data.dart';

/// Repository interface for managing game data persistence.
abstract class GameRepository {
  /// Load all games from storage.
  Future<List<Game>> loadGames();

  /// Save games to storage.
  Future<void> saveGames(List<Game> games);
}

/// Local file-based implementation of [GameRepository] using JSON storage.
/// 
/// - Stores games in statusxp_games.json in the app documents directory.
/// - On first run (or if file is missing/corrupted), seeds from sample_data.dart.
class LocalFileGameRepository implements GameRepository {
  static const _filename = 'statusxp_games.json';

  /// Get the full path to the games JSON file.
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Get the File object for the games JSON file.
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_filename');
  }

  @override
  Future<List<Game>> loadGames() async {
    try {
      final file = await _localFile;

      // First run: seed from sample data if file doesn't exist
      if (!await file.exists()) {
        await saveGames(sampleGames);
        return sampleGames;
      }

      // Read and parse JSON
      final contents = await file.readAsString();
      final jsonList = json.decode(contents) as List<dynamic>;
      final games = jsonList.map((json) => Game.fromJson(json as Map<String, dynamic>)).toList();

      return games;
    } catch (e) {
      // If JSON is corrupted or any error occurs, fallback to sample data and overwrite
      await saveGames(sampleGames);
      return sampleGames;
    }
  }

  @override
  Future<void> saveGames(List<Game> games) async {
    final file = await _localFile;
    final jsonList = games.map((game) => game.toJson()).toList();
    final jsonString = json.encode(jsonList);
    await file.writeAsString(jsonString);
  }
}
