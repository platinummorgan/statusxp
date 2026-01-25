import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/psn_service.dart';
import 'package:statusxp/data/xbox_service.dart';

/// Service that handles automatic background syncing
/// Checks last sync time and triggers sync if > 12 hours
/// 
/// IMPORTANT: Auto-sync is completely SEPARATE from rate limiting:
/// - Auto-sync: Runs every 12 hours in background (SharedPreferences)
/// - Rate limits: Apply only to manual "Sync Now" button presses (user_sync_history table)
/// - Auto-syncs pass isAutoSync=true flag and don't record in rate limit database
/// - Users can still manually sync whenever allowed by rate limits
class AutoSyncService {
  final SupabaseClient _client;
  final PSNService _psnService;
  final XboxService _xboxService;
  
  static const Duration _autoSyncInterval = Duration(hours: 12);
  static const String _psnLastSyncKey = 'last_psn_sync_time';
  static const String _xboxLastSyncKey = 'last_xbox_sync_time';
  static const String _steamLastSyncKey = 'last_steam_sync_time';
  
  // Prevent concurrent auto-sync checks (static to work across instances)
  static bool _isChecking = false;
  
  AutoSyncService(this._client, this._psnService, this._xboxService);
  
  /// Check and trigger auto-sync for all connected platforms
  Future<AutoSyncResult> checkAndSync() async {
    // Guard against concurrent checks
    if (_isChecking) {
      debugPrint('⚠️ Auto-sync already in progress, skipping...');
      return AutoSyncResult(
        psnSynced: false,
        xboxSynced: false,
        steamSynced: false,
      );
    }
    
    _isChecking = true;
    
    try {
      return await _performSync();
    } finally {
      _isChecking = false;
    }
  }
  
  Future<AutoSyncResult> _performSync() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return AutoSyncResult(
        psnSynced: false,
        xboxSynced: false,
        steamSynced: false,
      );
    }
    
    bool psnSynced = false;
    bool xboxSynced = false;
    bool steamSynced = false;
    
    // Run syncs SEQUENTIALLY to avoid overwhelming the system
    // Add delays between platform syncs
    try {
      // Check PSN first
      final psnLinked = await _isPlatformLinked('psn');
      debugPrint('🔍 PSN linked: $psnLinked');
      if (psnLinked && await _shouldSync(_psnLastSyncKey)) {
        psnSynced = await _triggerPSNSync();
        if (psnSynced) {
          debugPrint('⏳ Waiting 5 seconds before checking next platform...');
          await Future.delayed(const Duration(seconds: 5));
        }
      } else {
        debugPrint('⏭️ Skipping PSN sync (linked: $psnLinked, should sync: ${await _shouldSync(_psnLastSyncKey)})');
      }
    } catch (e) {
      debugPrint('Auto-sync PSN error: $e');
    }
    
    try {
      // Check Xbox second
      final xboxLinked = await _isPlatformLinked('xbox');
      debugPrint('🔍 Xbox linked: $xboxLinked');
      if (xboxLinked && await _shouldSync(_xboxLastSyncKey)) {
        xboxSynced = await _triggerXboxSync();
        if (xboxSynced) {
          debugPrint('⏳ Waiting 5 seconds before checking next platform...');
          await Future.delayed(const Duration(seconds: 5));
        }
      } else {
        debugPrint('⏭️ Skipping Xbox sync (linked: $xboxLinked, should sync: ${await _shouldSync(_xboxLastSyncKey)})');
      }
    } catch (e) {
      debugPrint('Auto-sync Xbox error: $e');
    }
    
    try {
      // Check Steam last
      final steamLinked = await _isPlatformLinked('steam');
      debugPrint('🔍 Steam linked: $steamLinked');
      if (steamLinked && await _shouldSync(_steamLastSyncKey)) {
        steamSynced = await _triggerSteamSync();
      } else {
        debugPrint('⏭️ Skipping Steam sync (linked: $steamLinked, should sync: ${await _shouldSync(_steamLastSyncKey)})');
      }
    } catch (e) {
      debugPrint('Auto-sync Steam error: $e');
    }
    
    return AutoSyncResult(
      psnSynced: psnSynced,
      xboxSynced: xboxSynced,
      steamSynced: steamSynced,
    );
  }
  
  /// Check if platform is linked for current user
  Future<bool> _isPlatformLinked(String platform) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;
      
      // Map platform names to correct column names
      final columnName = platform == 'psn' 
          ? 'psn_account_id'
          : platform == 'xbox'
              ? 'xbox_xuid'
              : 'steam_id'; // steam
      
      final response = await _client
          .from('profiles')
          .select(columnName)
          .eq('id', userId)
          .maybeSingle();
      
      if (response == null) return false;
      
      final accountId = response[columnName];
      return accountId != null && (accountId.toString()).isNotEmpty;
    } catch (e) {
      debugPrint('Error checking $platform link: $e');
      return false;
    }
  }
  
  /// Check if we should sync based on last sync time
  Future<bool> _shouldSync(String prefKey) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return false;

      final platform = prefKey.contains('psn') ? 'psn' :
                      prefKey.contains('xbox') ? 'xbox' : 'steam';
      final lastField = platform == 'psn' ? 'last_psn_sync_at' :
                       platform == 'xbox' ? 'last_xbox_sync_at' : 'last_steam_sync_at';
      final statusField = platform == 'psn' ? 'psn_sync_status' :
                         platform == 'xbox' ? 'xbox_sync_status' : 'steam_sync_status';

      final response = await _client
          .from('profiles')
          .select('$lastField,$statusField')
          .eq('id', userId)
          .maybeSingle();

      final status = response?[statusField] as String?;
      if (status == 'syncing' || status == 'pending' || status == 'cancelling') {
        debugPrint('⏭️ Skipping $platform auto-sync (status: $status)');
        return false;
      }

      final lastSyncStr = response?[lastField] as String?;
      debugPrint('📅 DB last sync for $platform: $lastSyncStr');

      if (lastSyncStr == null) {
        debugPrint('✅ No previous sync found in DB - should sync');
        return true;
      }

      final lastSync = DateTime.parse(lastSyncStr);
      final timeSinceSync = DateTime.now().difference(lastSync);

      debugPrint('⏰ Time since last $platform sync: ${timeSinceSync.inHours}h ${timeSinceSync.inMinutes % 60}m');
      return timeSinceSync >= _autoSyncInterval;
    } catch (e) {
      debugPrint('Error checking sync time for $prefKey: $e');
      return false; // Don't sync if we can't determine
    }
  }
  
  /// Trigger PSN sync in background
  Future<bool> _triggerPSNSync() async {
    try {
      debugPrint('🔄 Auto-triggering PSN sync...');
      
      // Update timestamp FIRST to prevent retriggers
      await _updateLastSyncTime(_psnLastSyncKey);
      
      await _psnService.startSync(
        syncType: 'incremental', // Faster incremental sync for auto-sync
        forceResync: false,
        isAutoSync: true, // Don't count against rate limits
      );
      
      debugPrint('✅ PSN auto-sync started successfully');
      return true;
    } on PSNRateLimitException catch (e) {
      debugPrint('⏱️ PSN sync rate limited: $e');
      // Rate limited - that's ok, just skip
      return false;
    } catch (e) {
      debugPrint('❌ PSN auto-sync error: $e');
      return false;
    }
  }
  
  /// Trigger Xbox sync in background
  Future<bool> _triggerXboxSync() async {
    try {
      debugPrint('🔄 Auto-triggering Xbox sync...');
      
      // Update timestamp FIRST to prevent retriggers
      await _updateLastSyncTime(_xboxLastSyncKey);
      
      await _xboxService.startSync(
        syncType: 'incremental',
        forceResync: false,
        isAutoSync: true, // Don't count against rate limits
      );
      
      debugPrint('✅ Xbox auto-sync started successfully');
      return true;
    } on XboxRateLimitException catch (e) {
      debugPrint('⏱️ Xbox sync rate limited: $e');
      return false;
    } catch (e) {
      debugPrint('❌ Xbox auto-sync error: $e');
      return false;
    }
  }
  
  /// Trigger Steam sync in background
  Future<bool> _triggerSteamSync() async {
    try {
      debugPrint('🔄 Auto-triggering Steam sync...');
      
      // Update timestamp FIRST to prevent retriggers
      await _updateLastSyncTime(_steamLastSyncKey);
      
      await _client.functions.invoke('steam-start-sync', body: {
        'isAutoSync': true, // Don't count against rate limits
      });
      
      debugPrint('✅ Steam auto-sync started successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Steam auto-sync error: $e');
      return false;
    }
  }
  
  /// Update the last sync time in SharedPreferences
  Future<void> _updateLastSyncTime(String prefKey) async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = DateTime.now().toIso8601String();
    final success = await prefs.setString(prefKey, timestamp);
    debugPrint('💾 Updating $prefKey to $timestamp (success: $success)');
    
    // Force commit to disk immediately
    await prefs.reload();
    final verified = prefs.getString(prefKey);
    debugPrint('✅ Verified $prefKey persisted: $verified');
  }
  
  /// Manually update sync time (call this after manual sync)
  Future<void> updatePSNSyncTime() async {
    debugPrint('📝 Manually updating PSN sync time');
    await _updateLastSyncTime(_psnLastSyncKey);
  }
  
  Future<void> updateXboxSyncTime() async {
    debugPrint('📝 Manually updating Xbox sync time');
    await _updateLastSyncTime(_xboxLastSyncKey);
  }
  
  Future<void> updateSteamSyncTime() async {
    debugPrint('📝 Manually updating Steam sync time');
    await _updateLastSyncTime(_steamLastSyncKey);
  }
  
  /// Get time until next auto-sync for a platform
  Future<Duration?> getTimeUntilNextSync(String platform) async {
    String prefKey;
    switch (platform.toLowerCase()) {
      case 'psn':
        prefKey = _psnLastSyncKey;
        break;
      case 'xbox':
        prefKey = _xboxLastSyncKey;
        break;
      case 'steam':
        prefKey = _steamLastSyncKey;
        break;
      default:
        return null;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString(prefKey);
      
      if (lastSyncStr == null) return Duration.zero;
      
      final lastSync = DateTime.parse(lastSyncStr);
      final nextSync = lastSync.add(_autoSyncInterval);
      final timeUntilNext = nextSync.difference(DateTime.now());
      
      return timeUntilNext.isNegative ? Duration.zero : timeUntilNext;
    } catch (e) {
      return null;
    }
  }
}

/// Result of auto-sync check
class AutoSyncResult {
  final bool psnSynced;
  final bool xboxSynced;
  final bool steamSynced;
  
  AutoSyncResult({
    required this.psnSynced,
    required this.xboxSynced,
    required this.steamSynced,
  });
  
  bool get anySynced => psnSynced || xboxSynced || steamSynced;
}
