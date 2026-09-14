import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session-only choices, shared across dashboard layouts and isolated by user.
final skippedRecommendationGamesProvider =
    StateProvider.family<Set<String>, String>((ref, userId) => <String>{});
