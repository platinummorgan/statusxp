import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'dart:html' as html show window;
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/widgets/psn_avatar.dart';
import 'package:statusxp/services/auto_sync_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:statusxp/utils/html.dart' as html;

/// New Dashboard Screen - Cross-Platform Overview
///
/// Displays StatusXP unified score and platform-specific stats
class NewDashboardScreen extends ConsumerStatefulWidget {
  const NewDashboardScreen({super.key});

  @override
  ConsumerState<NewDashboardScreen> createState() => _NewDashboardScreenState();
}

class _NewDashboardScreenState extends ConsumerState<NewDashboardScreen> {
  bool _showStatusXPHint = false;
  bool _isAutoSyncing = false;

  @override
  void initState() {
    super.initState();
    _checkIfShouldShowHint();
    // Refresh data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(dashboardStatsProvider);
      _checkAndTriggerAutoSync();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh data whenever we navigate back to this screen
    ref.invalidate(dashboardStatsProvider);
  }

  Future<void> _checkIfShouldShowHint() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenHint = prefs.getBool('has_seen_statusxp_hint') ?? false;
    if (!hasSeenHint && mounted) {
      setState(() {
        _showStatusXPHint = true;
      });
    }
  }

  Future<void> _hideHintPermanently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_statusxp_hint', true);
    if (mounted) {
      setState(() {
        _showStatusXPHint = false;
      });
    }
  }
  
  /// Check if it's been >12 hours and trigger auto-sync if needed
  Future<void> _checkAndTriggerAutoSync() async {
    if (_isAutoSyncing) return; // Already syncing
    
    setState(() => _isAutoSyncing = true);
    
    try {
      final psnService = ref.read(psnServiceProvider);
      final xboxService = ref.read(xboxServiceProvider);
      final supabase = ref.read(supabaseClientProvider);
      
      final autoSyncService = AutoSyncService(supabase, psnService, xboxService);
      final result = await autoSyncService.checkAndSync();
      
      if (result.anySynced && mounted) {
        // Show subtle notification that sync started
        final platforms = <String>[];
        if (result.psnSynced) platforms.add('PSN');
        if (result.xboxSynced) platforms.add('Xbox');
        if (result.steamSynced) platforms.add('Steam');
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Auto-syncing ${platforms.join(' & ')}...'),
            duration: const Duration(seconds: 2),
            backgroundColor: CyberpunkTheme.neonCyan.withOpacity(0.9),
          ),
        );
      }
    } catch (e) {
      debugPrint('Auto-sync check error: $e');
    } finally {
      if (mounted) {
        setState(() => _isAutoSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'StatusXP',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        actions: [
          if (kIsWeb) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () async {
                  // Detect iOS vs Android and open appropriate store
                  final userAgent = html.window.navigator?.userAgent?.toLowerCase() ?? '';
                  final isIOS = userAgent.contains('iphone') || userAgent.contains('ipad');
                  
                  final url = isIOS
                      ? Uri.parse('https://apps.apple.com/app/id6757080961')
                      : Uri.parse('https://play.google.com/store/apps/details?id=com.statusxp.statusxp');
                  
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.phone_android, size: 18, color: CyberpunkTheme.neonCyan),
                label: const Text(
                  'Also on Android & iOS',
                  style: TextStyle(
                    color: CyberpunkTheme.neonCyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: CyberpunkTheme.neonCyan.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: CyberpunkTheme.neonCyan.withOpacity(0.3)),
                  ),
                ),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              context.push('/settings');
            },
          ),
        ],
      ),
      body: dashboardStatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading dashboard: $error'),
            ],
          ),
        ),
        data: (stats) => stats == null
            ? const Center(child: Text('No data available'))
            : _buildDashboardContent(context, theme, stats),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    ThemeData theme,
    DashboardStats stats,
  ) {
    return Container(
      decoration: CyberpunkTheme.gradientBackground(),
      child: RefreshIndicator(
        onRefresh: () async {
          ref.refreshCoreData();
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Username header with avatar
                  _buildUserHeader(context, theme, stats),

                  const SizedBox(height: 32),

                  // StatusXP large circle (center top)
                  _buildStatusXPCircle(stats.totalStatusXP),

                  const SizedBox(height: 32),

                  // Platform circles row
                  _buildPlatformCircles(stats),

                  const SizedBox(height: 40),

                  // Quick Actions
                  _buildQuickActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(
    BuildContext context,
    ThemeData theme,
    DashboardStats stats,
  ) {
    return Row(
      children: [
        // Platform Avatar (only show PS Plus badge when platform is PSN)
        PsnAvatar(
          avatarUrl: stats.avatarUrl,
          isPsPlus: stats.displayPlatform == 'psn' ? stats.isPsPlus : false,
          size: 64,
          borderColor: CyberpunkTheme.neonCyan,
        ),

        const SizedBox(width: 16),

        // Username with platform indicator
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stats.displayName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  fontSize: 28,
                  height: 1.1,
                  shadows: [
                    ...CyberpunkTheme.neonGlow(
                      color: CyberpunkTheme.neonCyan,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Platform indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _getPlatformColor(
                    stats.displayPlatform,
                  ).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _getPlatformColor(stats.displayPlatform),
                    width: 1,
                  ),
                ),
                child: Text(
                  stats.displayPlatform.toUpperCase(),
                  style: TextStyle(
                    color: _getPlatformColor(stats.displayPlatform),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusXPCircle(double totalStatusXP) {
    return GestureDetector(
      onTap: () {
        _hideHintPermanently();
        _showStatusXPBreakdown(context);
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: CyberpunkTheme.neonPurple, width: 4),
              boxShadow: [
                BoxShadow(
                  color: CyberpunkTheme.neonPurple.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'StatusXP',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatNumber(totalStatusXP.toInt()),
                  style: TextStyle(
                    color: CyberpunkTheme.neonPurple,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                    shadows: [
                      ...CyberpunkTheme.neonGlow(
                        color: CyberpunkTheme.neonPurple,
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // One-time hint badge
          if (_showStatusXPHint)
            Positioned(
              bottom: -10,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showStatusXPHint ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: CyberpunkTheme.neonPurple.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: CyberpunkTheme.neonPurple,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CyberpunkTheme.neonPurple.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: Colors.white,
                          size: 12,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'TAP FOR BREAKDOWN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlatformCircles(DashboardStats stats) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // PSN Circle
        _buildPlatformCircle(
          label: 'Platinums',
          value: stats.psnStats.platinums.toString(),
          subtitle: '${stats.psnStats.gamesCount} Games',
          bottomLabel:
              '${stats.psnStats.averagePerGame.toStringAsFixed(0)} AVG/GAME',
          color: const Color(0xFF00A8E1), // PlayStation Blue
        ),

        // Xbox Circle
        _buildPlatformCircle(
          label: 'Xbox Gamerscore',
          value: stats.xboxStats.gamerscore.toString(),
          subtitle: '${stats.xboxStats.gamesCount} Games',
          bottomLabel:
              '${stats.xboxStats.achievementsUnlocked} ACHIEVEMENTS',
          color: const Color(0xFF107C10), // Xbox Green
        ),

        // Steam Circle
        _buildPlatformCircle(
          label: 'Steam Achievs',
          value: stats.steamStats.achievementsUnlocked.toString(),
          subtitle: '${stats.steamStats.gamesCount} Games',
          bottomLabel:
              '${stats.steamStats.averagePerGame.toStringAsFixed(0)} AVG/GAME',
          color: const Color(0xFF66C0F4), // Steam Blue
        ),
      ],
    );
  }

  Widget _buildPlatformCircle({
    required String label,
    required String value,
    required String subtitle,
    required String bottomLabel,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  shadows: [
                    Shadow(color: color.withOpacity(0.6), blurRadius: 8),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // AVG/GAME label below circle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.3), width: 1),
          ),
          child: Column(
            children: [
              Text(
                'AVG/GAME',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                bottomLabel.split(' ')[0], // Just the number
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUICK ACTIONS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 2.5,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 16),

        _buildActionButton(
          label: 'View Games',
          icon: Icons.videogame_asset,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/unified-games');
          },
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          label: 'Browse All Games',
          icon: Icons.explore,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/games/browse');
          },
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          label: 'Status Poster',
          icon: Icons.image,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/poster');
          },
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          label: 'Flex Room',
          icon: Icons.emoji_events,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/flex-room');
          },
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          label: 'Find Co-op Partners',
          icon: Icons.handshake,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/coop-partners');
          },
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          label: 'Achievements',
          icon: Icons.stars,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/achievements');
          },
        ),

        const SizedBox(height: 12),

        _buildActionButton(
          label: 'Leaderboards',
          icon: Icons.leaderboard,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/leaderboards');
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: CyberpunkTheme.glassLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: CyberpunkTheme.neonCyan.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: CyberpunkTheme.neonCyan, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: CyberpunkTheme.neonCyan.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Color _getPlatformColor(String platform) {
    switch (platform) {
      case 'psn':
        return const Color(0xFF00A8E1);
      case 'xbox':
        return const Color(0xFF107C10);
      case 'steam':
        return const Color(0xFF66C0F4);
      default:
        return CyberpunkTheme.neonCyan;
    }
  }

  String _formatNumber(int number) {
    // Show full number with comma separators
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  void _showStatusXPBreakdown(BuildContext context) {
    final dashboardStats = ref.read(dashboardStatsProvider).value;
    if (dashboardStats == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E27).withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: CyberpunkTheme.neonPurple.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: CyberpunkTheme.neonPurple.withOpacity(0.3),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.leaderboard,
                    color: CyberpunkTheme.neonPurple,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'STATUSXP BREAKDOWN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.white70,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),
              
              // Platform breakdown
              _buildBreakdownRow(
                'PlayStation',
                dashboardStats.psnStats.statusXP,
                const Color(0xFF00A8E1),
              ),
              const SizedBox(height: 16),
              _buildBreakdownRow(
                'Xbox',
                dashboardStats.xboxStats.statusXP,
                const Color(0xFF107C10),
              ),
              const SizedBox(height: 16),
              _buildBreakdownRow(
                'Steam',
                dashboardStats.steamStats.statusXP,
                const Color(0xFF66C0F4),
              ),
              
              const Divider(color: Colors.white24, height: 32),
              
              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    _formatNumber(dashboardStats.totalStatusXP.toInt()),
                    style: TextStyle(
                      color: CyberpunkTheme.neonPurple,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        ...CyberpunkTheme.neonGlow(
                          color: CyberpunkTheme.neonPurple,
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownRow(String platform, double xp, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            platform.toUpperCase(),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Text(
          _formatNumber(xp.toInt()),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}
