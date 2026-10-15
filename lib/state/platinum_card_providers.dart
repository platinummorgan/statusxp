import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/data/repositories/platinum_card_repository.dart';
import 'package:statusxp/domain/platinum_card.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/state/sync_completion_provider.dart';
import 'package:statusxp/services/premium_access.dart';

final platinumCardRepositoryProvider = Provider(
  (ref) => PlatinumCardRepository(ref.watch(supabaseClientProvider)),
);
final platinumCardsProvider =
    FutureProvider.autoDispose<List<PlatinumCardData>>((ref) {
      if (ref.watch(currentUserIdProvider) == null) return const [];
      ref.watch(syncCompletionProvider);
      return ref.watch(platinumCardRepositoryProvider).list();
    });
final platinumCelebrationProvider =
    FutureProvider.autoDispose<PlatinumCelebration?>((ref) {
      if (ref.watch(currentUserIdProvider) == null) return null;
      ref.watch(syncCompletionProvider);
      return ref.watch(platinumCardRepositoryProvider).discover();
    });
final platinumPremiumProvider = FutureProvider.autoDispose<bool>((ref) async {
  ref.watch(currentUserIdProvider);
  ref.watch(authStateProvider);
  return hasActivePremium(
    await readPremiumEntitlement(ref.watch(supabaseClientProvider)),
  );
});
