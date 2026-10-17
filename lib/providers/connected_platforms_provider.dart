import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/state/statusxp_providers.dart';

/// Provider that detects which gaming platforms the user has connected
/// Returns a set of platform codes: {'psn', 'xbox', 'steam'}
final connectedPlatformsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) return {};

  try {
    final profile = await supabase
        .from('profiles')
        .select('psn_account_id, xbox_xuid, steam_id')
        .eq('id', userId)
        .single();

    final platforms = <String>{};

    // Check if PSN is connected (has PSN ID)
    if (profile['psn_account_id'] != null &&
        (profile['psn_account_id'] as String).isNotEmpty) {
      platforms.add('psn');
    }

    // Display names can be missing or stale; use the linked account identity.
    if (profile['xbox_xuid'] != null &&
        (profile['xbox_xuid'] as String).isNotEmpty) {
      platforms.add('xbox');
    }

    // Check if Steam is connected (has Steam ID).
    if (profile['steam_id'] != null &&
        (profile['steam_id'] as String).isNotEmpty) {
      platforms.add('steam');
    }

    return platforms;
  } catch (e) {
    return {};
  }
});

/// Helper provider to check if user has a specific platform connected
final hasPlatformProvider = Provider.family<bool, String>((ref, platform) {
  final connectedPlatforms = ref.watch(connectedPlatformsProvider);
  return connectedPlatforms.maybeWhen(
    data: (platforms) => platforms.contains(platform),
    orElse: () => false,
  );
});

/// Provider to check if user has all platforms connected
final hasAllPlatformsProvider = Provider<bool>((ref) {
  final connectedPlatforms = ref.watch(connectedPlatformsProvider);
  return connectedPlatforms.maybeWhen(
    data: (platforms) => platforms.containsAll(['psn', 'xbox', 'steam']),
    orElse: () => false,
  );
});

/// Provider to count connected platforms
final connectedPlatformCountProvider = Provider<int>((ref) {
  final connectedPlatforms = ref.watch(connectedPlatformsProvider);
  return connectedPlatforms.maybeWhen(
    data: (platforms) => platforms.length,
    orElse: () => 0,
  );
});
