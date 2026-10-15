import 'package:flutter_test/flutter_test.dart';
import 'package:statusxp/state/sync_completion_provider.dart';

SyncCompletionSnapshot snapshot(
  String status, {
  String? completed,
  String user = 'user',
  String platform = 'psn',
}) => SyncCompletionSnapshot({
  'user_id': user,
  '${platform}_sync_status': status,
  'last_${platform}_sync_at': completed,
});

void main() {
  for (final platform in SyncCompletionSnapshot.platforms) {
    test('$platform completion refreshes after leaving the sync screen', () {
      final before = snapshot('syncing', platform: platform);
      final after = snapshot(
        'success',
        platform: platform,
        completed: '2026-10-13T10:00:00Z',
      );
      expect(after.shouldRefreshAfter(before), isTrue);
      expect(after.shouldRefreshAfter(after), isFalse);
    });
    test(
      '$platform no-new-achievements sync refreshes via its new timestamp',
      () {
        final before = snapshot(
          'success',
          platform: platform,
          completed: '2026-10-12T10:00:00Z',
        );
        final after = snapshot(
          'success',
          platform: platform,
          completed: '2026-10-13T10:00:00Z',
        );
        expect(after.shouldRefreshAfter(before), isTrue);
        expect(before.shouldRefreshAfter(after), isFalse);
      },
    );
  }
  test(
    'initial/reconnected status and account changes refresh old cached data',
    () {
      final current = snapshot('success');
      expect(current.shouldRefreshAfter(null), isTrue);
      expect(
        current.shouldRefreshAfter(snapshot('success', user: 'another')),
        isTrue,
      );
    },
  );
  test('starting work does not reload completed stats', () {
    expect(
      snapshot('syncing').shouldRefreshAfter(snapshot('success')),
      isFalse,
    );
  });
  test('partial failure or cancellation reloads saved partial data', () {
    expect(snapshot('error').shouldRefreshAfter(snapshot('syncing')), isTrue);
    expect(
      snapshot('stopped').shouldRefreshAfter(snapshot('cancelling')),
      isTrue,
    );
  });
}
