import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/data/psn_service.dart';
import 'package:statusxp/data/xbox_service.dart';

/// Service that handles automatic background syncing
/// Checks last sync time and triggers sync if > 12 hours
class AutoSyncService {
  final SupabaseClient _client;
  final PSNService _psnService;
  final XboxService _xboxService;
  
  static const Duration _autoSyncInterval = Duration(hours: 12);
  static const String _psnLastSyncKey = 'last_psn_sync_time';
  static const String _xboxLastSyncKey = 'last_xbox_sync_time';
  static const String _steamLastSyncKey = 'last_steam_sync_time';
  
  AutoSyncService(this._client, this._psnService, this._xboxService);
  
  /// Check and trigger auto-sync for all connected platforms
  Future<AutoSyncResult> checkAndSync() async {
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
    
    try {
      // Check PSN
      final psnLinked = await _isPlatformLinked('psn');
      if (psnLinked && await _shouldSync(_psnLastSyncKey)) {
        psnSynced = await _triggerPSNSync();
      }
    } catch (e) {
      debugPrint('Auto-sync PSN error: $e');
    }
    
    try {
      // Check Xbox
      final xboxLinked = await _isPlatformLinked('xbox');
      if (xboxLinked && await _shouldSync(_xboxLastSyncKey)) {
        xboxSynced = await _triggerXboxSync();
      }
    } catch (e) {
      debugPrint('Auto-sync Xbox error: $e');
    }
    
    // TODO: Steam when implemented
    
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
      
      final response = await _client
          .from('profiles')
          .select('${platform}_account_id')
          .eq('id', userId)
          .maybeSingle();
      
      if (response == null) return false;
      
      final accountId = response['${platform}_account_id'];
      return accountId != null && accountId.toString().isNotEmpty;
    } catch (e) {
      debugPrint('Error checking $platform link: $e');
      return false;
    }
  }
  
  /// Check if we should sync based on last sync time
  Future<bool> _shouldSync(String prefKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncStr = prefs.getString(prefKey);
      
      if (lastSyncStr == null) {
        // Never synced before - trigger sync
        return true;
      }
      
      final lastSync = DateTime.parse(lastSyncStr);
      final timeSinceSync = DateTime.now().difference(lastSync);
      
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
      
      await _psnService.startSync(
        syncType: 'incremental', // Faster incremental sync for auto-sync
        forceResync: false,
      );
      
      // Update last sync time
      await _updateLastSyncTime(_psnLastSyncKey);
      
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
      
      await _xboxService.startSync(
        syncType: 'incremental',
        forceResync: false,
      );
      
      // Update last sync time
      await _updateLastSyncTime(_xboxLastSyncKey);
      
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
  
  /// Update the last sync time in SharedPreferences
  Future<void> _updateLastSyncTime(String prefKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefKey, DateTime.now().toIso8601String());
  }
  
  /// Manually update sync time (call this after manual sync)
  Future<void> updatePSNSyncTime() async {
    await _updateLastSyncTime(_psnLastSyncKey);
  }
  
  Future<void> updateXboxSyncTime() async {
    await _updateLastSyncTime(_xboxLastSyncKey);
  }
  
  Future<void> updateSteamSyncTime() async {
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
