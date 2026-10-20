import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/data/repositories/engagement_repository.dart';
import 'package:statusxp/domain/engagement_hub_data.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/services/crash_reporting_service.dart';

final engagementRepositoryProvider = Provider<EngagementRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return EngagementRepository(client);
});

// Retain successful sections only for the current signed-in account.
final _engagementCacheProvider = Provider<Map<String, Object>>((ref) {
  ref.watch(currentUserIdProvider);
  return {};
});

bool _temporaryReadFailure(Object error) {
  if (error is TimeoutException) return true;
  if (error is PostgrestException) {
    return [
      '57014',
      '53300',
      '57P01',
      '08006',
      '502',
      '503',
      '504',
    ].contains(error.code);
  }
  final message = error.toString().toLowerCase();
  return [
    'socketexception',
    'clientexception',
    'failed to fetch',
    'failed host lookup',
    'connection reset',
    'network request failed',
  ].any(message.contains);
}

Future<T> _loadSection<T extends Object>(
  Ref ref,
  String key,
  Future<T> Function() load,
) async {
  final cache = ref.watch(_engagementCacheProvider);
  var disposed = false;
  Timer? retry;
  ref.onDispose(() {
    disposed = true;
    retry?.cancel();
  });
  final elapsed = Stopwatch()..start();
  try {
    final value = await load().timeout(const Duration(seconds: 12));
    if (!disposed) cache[key] = value;
    return value;
  } catch (error, stack) {
    final lastReport = cache['reported:$key'] as DateTime?;
    final now = DateTime.now();
    if (!disposed &&
        (lastReport == null ||
            now.difference(lastReport) >= const Duration(minutes: 1))) {
      cache['reported:$key'] = now;
      final category = error is PostgrestException
          ? error.code
          : error.runtimeType.toString();
      unawaited(
        CrashReportingService.instance
            .recordError(
              StateError('Engagement read failed ($category)'),
              stack,
              reason: '$key after ${elapsed.elapsedMilliseconds}ms',
            )
            .catchError((Object _) {}),
      );
    }
    if (!disposed && _temporaryReadFailure(error)) {
      retry = Timer(const Duration(seconds: 10), ref.invalidateSelf);
    }
    // Preserve real data while retrying a temporary failure. Permanent failures
    // must not be presented as successful reads (especially after auth changes).
    final saved = cache[key];
    if (_temporaryReadFailure(error) && saved is T) return saved;
    rethrow;
  }
}

final engagementSnapshotProvider =
    FutureProvider.autoDispose<EngagementSnapshot>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');
      final repository = ref.watch(engagementRepositoryProvider);
      return _loadSection(
        ref,
        'get_user_engagement_snapshot',
        () => repository.getEngagementSnapshot(userId),
      );
    });

final socialTargetsProvider = FutureProvider.autoDispose<List<SocialTarget>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('Not authenticated');
  final repository = ref.watch(engagementRepositoryProvider);
  return _loadSection(
    ref,
    'get_social_graph_snapshot',
    () => repository.getSocialTargets(userId),
  );
});

final socialHighlightsProvider =
    FutureProvider.autoDispose<List<SocialHighlight>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');
      final repository = ref.watch(engagementRepositoryProvider);
      return _loadSection(
        ref,
        'get_social_activity_highlights',
        () => repository.getSocialHighlights(userId),
      );
    });

final playNextRecommendationsProvider =
    FutureProvider.autoDispose<List<PlayNextRecommendation>>((ref) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');
      final repository = ref.watch(engagementRepositoryProvider);
      return _loadSection(
        ref,
        'get_play_next_recommendations',
        () => repository.getPlayNextRecommendations(userId),
      );
    });
