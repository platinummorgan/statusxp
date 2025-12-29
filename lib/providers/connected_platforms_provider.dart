import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider that detects which gaming platforms the user has connected
/// Returns a set of platform codes: {'psn', 'xbox', 'steam'}
final connectedPlatformsProvider = FutureProvider.autoDispose<Set<String>>((ref) async {
  final supabase = Supabase.instance.client;
  final userId = supabase.auth.currentUser?.id;
  
  if (userId == null) return {};

  try {
    final profile = await supabase
        .from('profiles')
        .select('psn_online_id, xbox_gamertag, steam_id, steam_display_name')
        .eq('id', userId)
        .single();

    final platforms = <String>{};
    
    // Check if PSN is connected (has PSN ID)
    if (profile['psn_online_id'] != null && 
        (profile['psn_online_id'] as String).isNotEmpty) {
      platforms.add('psn');
    }
    
    // Check if Xbox is connected (has gamertag)
    if (profile['xbox_gamertag'] != null && 
        (profile['xbox_gamertag'] as String).isNotEmpty) {
      platforms.add('xbox');
    }
    
    // Check if Steam is connected (has Steam ID or display name)
    if ((profile['steam_id'] != null && (profile['steam_id'] as String).isNotEmpty) ||
        (profile['steam_display_name'] != null && (profile['steam_display_name'] as String).isNotEmpty)) {
      platforms.add('steam');
    }

    return platforms;
  } catch (e) {
    print('Error fetching connected platforms: $e');
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
