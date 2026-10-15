import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/state/statusxp_providers.dart';

class SecurityReconnectRequirement {
  const SecurityReconnectRequirement({
    required this.platform,
    required this.accountId,
    required this.resetReported,
    required this.syncActive,
  });

  final String platform;
  final String accountId;
  final bool resetReported;
  final bool syncActive;

  String get label => switch (platform) {
    'psn' => 'PlayStation',
    'xbox' => 'Xbox',
    'steam' => 'Steam',
    _ => throw StateError('Unsupported reconnect platform'),
  };
}

abstract class SecurityReconnectRepository {
  Future<List<SecurityReconnectRequirement>> load();
  Future<void> reportReset(String platform);
  Future<void> verifySteam();
  Future<void> stopSync(String platform);
}

class SupabaseSecurityReconnectRepository
    implements SecurityReconnectRepository {
  SupabaseSecurityReconnectRepository(this.client);
  final SupabaseClient client;

  @override
  Future<List<SecurityReconnectRequirement>> load() async {
    final rows = await client.rpc('activate_security_reconnect');
    return (rows as List)
        .map((row) {
          final data = Map<String, dynamic>.from(row as Map);
          final platform = data['platform'] as String;
          if (!const ['psn', 'xbox', 'steam'].contains(platform)) {
            throw StateError('Unsupported reconnect platform');
          }
          return SecurityReconnectRequirement(
            platform: platform,
            accountId: data['account_id'] as String,
            resetReported: data['reset_reported'] == true,
            syncActive: data['sync_active'] == true,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> reportReset(String platform) async {
    await client.rpc(
      'report_security_provider_reset',
      params: {'p_platform': platform},
    );
  }

  @override
  Future<void> verifySteam() async {
    final response = await client.functions.invoke('verify-security-reconnect');
    if (response.status != 200 || response.data?['success'] != true) {
      throw StateError('Steam reconnect could not be verified');
    }
  }

  @override
  Future<void> stopSync(String platform) async {
    final response = await client.functions.invoke('$platform-stop-sync');
    if (response.status != 200 || response.data?['success'] != true) {
      throw StateError('Sync stop could not be requested');
    }
  }
}

final securityReconnectRepositoryProvider =
    Provider<SecurityReconnectRepository>((ref) {
      return SupabaseSecurityReconnectRepository(
        ref.watch(supabaseClientProvider),
      );
    });

final securityReconnectRequirementsProvider =
    FutureProvider.autoDispose<List<SecurityReconnectRequirement>>((ref) {
      final owner = ref.watch(currentUserIdProvider);
      if (owner == null) return Future.value(const []);
      return ref.watch(securityReconnectRepositoryProvider).load();
    });
