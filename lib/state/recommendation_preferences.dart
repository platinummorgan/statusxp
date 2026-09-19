import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/domain/recommendation_goal.dart';

final recommendationGoalsProvider =
    StateNotifierProvider.family<
      RecommendationGoalsController,
      AsyncValue<RecommendationGoals>,
      String
    >((ref, userId) => RecommendationGoalsController(userId));

class RecommendationGoalsController
    extends StateNotifier<AsyncValue<RecommendationGoals>> {
  RecommendationGoalsController(this.userId) : super(const AsyncLoading()) {
    _load();
  }
  final String userId;
  String get _key => 'recommendation_goals_v1_$userId';
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      final goals = value == null
          ? const RecommendationGoals()
          : RecommendationGoals.fromJson(
              jsonDecode(value) as Map<String, dynamic>,
            );
      if (mounted) state = AsyncData(goals);
    } catch (error, stack) {
      if (mounted) state = AsyncError(error, stack);
    }
  }

  Future<void> save(RecommendationGoals goals) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_key, jsonEncode(goals.toJson()));
    if (!saved) throw StateError('Could not save goals');
    if (mounted) state = AsyncData(goals);
  }
}

/// Session-only choices, shared across dashboard layouts and isolated by user.
final skippedRecommendationGamesProvider =
    StateProvider.family<Set<String>, String>((ref, userId) => <String>{});
