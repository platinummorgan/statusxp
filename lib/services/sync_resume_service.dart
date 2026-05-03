import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/psn_service.dart';
import 'package:statusxp/data/xbox_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/utils/supabase_guard.dart';

import 'package:statusxp/utils/statusxp_logger.dart';

/// Service that checks for interrupted syncs on app startup and resumes them.
///
/// When the app is interrupted (e.g., Railway reset, app crash), sync statuses
/// may be left in 'syncing' or 'pending' state. This service detects these
/// cases and automatically resumes the syncs.
class SyncResumeService {
  final SupabaseClient? _client;
  final PSNService _psnService;
  final XboxService _xboxService;

  SyncResumeService({
    required SupabaseClient? client,
    required PSNService psnService,
    required XboxService xboxService,
  }) : _client = client,
       _psnService = psnService,
       _xboxService = xboxService;

  /// Check and resume any interrupted syncs.
  ///
  /// Should be called once on app startup after authentication.
  ///
  /// Only resumes syncs that have been in 'syncing' state for more than 5 minutes,
  /// indicating they were truly interrupted (Railway reset, app crash) rather than
  /// legitimately running.
  Future<void> checkAndResumeInterruptedSyncs() async {
    try {
      final client = _client;
      if (client == null) {
        return;
      }

      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        return;
      }

      // Get current user profile with sync statuses and timestamps
      final response = await client
          .from('profiles')
          .select(
            'psn_sync_status, xbox_sync_status, steam_sync_status, psn_online_id, xbox_gamertag, steam_id, last_psn_sync_at, last_xbox_sync_at, last_steam_sync_at',
          )
          .eq('id', userId)
          .maybeSingle();

      if (response == null) {
        return;
      }

      final psnStatus = response['psn_sync_status'] as String?;
      final xboxStatus = response['xbox_sync_status'] as String?;
      final steamStatus = response['steam_sync_status'] as String?;

      final hasPSN = response['psn_online_id'] != null;
      final hasXbox = response['xbox_gamertag'] != null;
      final hasSteam = response['steam_id'] != null;

      final now = DateTime.now();
      const staleThreshold = Duration(minutes: 5);

      // Check PSN
      if (hasPSN && (psnStatus == 'syncing' || psnStatus == 'pending')) {
        final lastSync = response['last_psn_sync_at'] != null
            ? DateTime.parse(response['last_psn_sync_at'] as String)
            : null;

        // Only resume if sync started more than 5 minutes ago (truly interrupted)
        // If lastSync is null or old, it's likely interrupted
        if (lastSync == null || now.difference(lastSync) > staleThreshold) {
          statusxpLog(
            '🔄 Resuming interrupted PSN sync (was: $psnStatus, last sync: ${lastSync != null ? now.difference(lastSync).inMinutes : "never"} minutes ago)',
          );
          _resumePSNSync();
        } else {
          statusxpLog(
            'ℹ️ PSN sync appears to be actively running (started ${now.difference(lastSync).inSeconds} seconds ago), not resuming',
          );
        }
      }

      // Check Xbox
      if (hasXbox && (xboxStatus == 'syncing' || xboxStatus == 'pending')) {
        final lastSync = response['last_xbox_sync_at'] != null
            ? DateTime.parse(response['last_xbox_sync_at'] as String)
            : null;

        if (lastSync == null || now.difference(lastSync) > staleThreshold) {
          statusxpLog(
            '🔄 Resuming interrupted Xbox sync (was: $xboxStatus, last sync: ${lastSync != null ? now.difference(lastSync).inMinutes : "never"} minutes ago)',
          );
          _resumeXboxSync();
        } else {
          statusxpLog(
            'ℹ️ Xbox sync appears to be actively running (started ${now.difference(lastSync).inSeconds} seconds ago), not resuming',
          );
        }
      }

      // Check Steam (if Steam sync service exists in the future)
      if (hasSteam && (steamStatus == 'syncing' || steamStatus == 'pending')) {
        final lastSync = response['last_steam_sync_at'] != null
            ? DateTime.parse(response['last_steam_sync_at'] as String)
            : null;

        if (lastSync == null || now.difference(lastSync) > staleThreshold) {
          statusxpLog(
            '🔄 Steam sync resume detected (was: $steamStatus, last sync: ${lastSync != null ? now.difference(lastSync).inMinutes : "never"} minutes ago) - not yet implemented',
          );
          // TODO: Implement Steam sync resume when Steam sync service is available
        }
      }
    } catch (e) {
      statusxpLog('⚠️ Error checking for interrupted syncs: $e');
      // Don't throw - this is a background service, shouldn't crash the app
    }
  }

  /// Resume PSN sync without throwing errors to the UI.
  ///
  /// Automatically continues the sync from where it left off with retry logic.
  /// Does not disrupt the app even if resume fails.
  Future<void> _resumePSNSync() async {
    try {
      // Retry with exponential backoff in case of transient failures
      int retries = 0;
      const maxRetries = 2;

      while (retries < maxRetries) {
        try {
          await _psnService.continueSync();
          statusxpLog('✅ PSN sync resumed successfully from checkpoint');
          return;
        } catch (e) {
          final errorStr = e.toString();

          // Handle 409 Conflict (sync already running) - this is actually fine!
          if (errorStr.contains('409') ||
              errorStr.contains('already in progress')) {
            statusxpLog('ℹ️ PSN sync is already running - no action needed');
            return;
          }

          retries++;
          if (retries < maxRetries) {
            statusxpLog(
              '⚠️ PSN sync resume attempt $retries failed, retrying...',
            );
            await Future.delayed(
              Duration(milliseconds: 500 * (1 << (retries - 1))),
            );
          }
        }
      }

      // If all retries failed, don't error - just log and continue
      statusxpLog(
        '⚠️ PSN sync resume failed after $maxRetries attempts - will retry on next app resume',
      );
    } catch (e) {
      statusxpLog('⚠️ Unexpected error in PSN sync resume: $e');
      // Don't rethrow - allow app to continue even if resume fails
    }
  }

  /// Resume Xbox sync without throwing errors to the UI.
  ///
  /// Automatically continues the sync from where it left off with retry logic.
  /// Does not disrupt the app even if resume fails.
  Future<void> _resumeXboxSync() async {
    try {
      // Retry with exponential backoff in case of transient failures
      int retries = 0;
      const maxRetries = 2;

      while (retries < maxRetries) {
        try {
          await _xboxService.continueSync();
          statusxpLog('✅ Xbox sync resumed successfully from checkpoint');
          return;
        } catch (e) {
          final errorStr = e.toString();

          // Handle 409 Conflict (sync already running) - this is actually fine!
          if (errorStr.contains('409') ||
              errorStr.contains('already in progress')) {
            statusxpLog('ℹ️ Xbox sync is already running - no action needed');
            return;
          }

          retries++;
          if (retries < maxRetries) {
            statusxpLog(
              '⚠️ Xbox sync resume attempt $retries failed, retrying...',
            );
            await Future.delayed(
              Duration(milliseconds: 500 * (1 << (retries - 1))),
            );
          }
        }
      }

      // If all retries failed, don't error - just log and continue
      statusxpLog(
        '⚠️ Xbox sync resume failed after $maxRetries attempts - will retry on next app resume',
      );
    } catch (e) {
      statusxpLog('⚠️ Unexpected error in Xbox sync resume: $e');
      // Don't rethrow - allow app to continue even if resume fails
    }
  }
}

/// Provider for SyncResumeService
final syncResumeServiceProvider = Provider<SyncResumeService>((ref) {
  final client = tryGetSupabaseClient();
  final psnService = ref.watch(psnServiceProvider);
  final xboxService = ref.watch(xboxServiceProvider);

  return SyncResumeService(
    client: client,
    psnService: psnService,
    xboxService: xboxService,
  );
});
