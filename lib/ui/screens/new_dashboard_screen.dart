import 'dart:ui';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:statusxp/domain/unified_game.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/screens/game_achievements_screen.dart';
import 'package:statusxp/ui/widgets/psn_avatar.dart';
import 'package:statusxp/services/auto_sync_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// New Dashboard Screen - Cross-Platform Overview
///
/// Displays StatusXP unified score and platform-specific stats
class NewDashboardScreen extends ConsumerStatefulWidget {
  const NewDashboardScreen({super.key});

  @override
  ConsumerState<NewDashboardScreen> createState() => _NewDashboardScreenState();
}

class _NewDashboardScreenState extends ConsumerState<NewDashboardScreen>
    with TickerProviderStateMixin {
  bool _showStatusXPHint = false;
  bool _isAutoSyncing = false;
  String? _backgroundMode; // 'auto', 'shuffle', game title, or 'custom:url'
  String? _customBackgroundUrl; // URL of custom uploaded image
  int? _shuffleSeed; // Store shuffle seed to prevent changing on scroll
  bool _isUploadingCustom = false;
  
  final SubscriptionService _subscriptionService = SubscriptionService();
  
  // Scroll controller for parallax effect
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  
  // Animation controllers for counting effects
  late AnimationController _statusXPController;
  late AnimationController _platformsController;
  late AnimationController _entranceController;
  late AnimationController _shimmerController;
  late Animation<double> _statusXPAnimation;
  late Animation<double> _platformsAnimation;
  late Animation<double> _userHeaderAnimation;
  late Animation<double> _statusXPCircleAnimation;
  late Animation<double> _platformCirclesAnimation;
  late Animation<Offset> _userHeaderSlide;
  late Animation<Offset> _statusXPCircleSlide;
  late Animation<Offset> _platformCirclesSlide;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _statusXPController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _platformsController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(); // Continuously loop
    
    _statusXPAnimation = CurvedAnimation(
      parent: _statusXPController,
      curve: Curves.easeOutCubic,
    );
    
    _platformsAnimation = CurvedAnimation(
      parent: _platformsController,
      curve: Curves.easeOutCubic,
    );
    
    _shimmerAnimation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
    
    // Staggered entrance animations
    _userHeaderAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );
    
    _statusXPCircleAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
    );
    
    _platformCirclesAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
    );
    
    // Slide animations
    _userHeaderSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(_userHeaderAnimation);
    
    _statusXPCircleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_statusXPCircleAnimation);
    
    _platformCirclesSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(_platformCirclesAnimation);
    
    // Listen to scroll for parallax effect
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
    
    _checkIfShouldShowHint();
    _loadBackgroundMode();
    // Generate shuffle seed once on load
    _shuffleSeed = DateTime.now().millisecondsSinceEpoch;
    // Refresh data when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(dashboardStatsProvider);
      _checkAndTriggerAutoSync();
      // Start animations after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _entranceController.forward();
          _statusXPController.forward();
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) _platformsController.forward();
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _statusXPController.dispose();
    _platformsController.dispose();
    _entranceController.dispose();
    _shimmerController.dispose();
    super.dispose();
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
  
  Future<void> _loadBackgroundMode() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString('background_mode') ?? 'auto';
    final customUrl = prefs.getString('custom_background_url');
    if (mounted) {
      setState(() {
        _backgroundMode = mode;
        _customBackgroundUrl = customUrl;
      });
    }
  }
  
  Future<void> _setBackgroundMode(String mode, {String? customUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('background_mode', mode);
    if (customUrl != null) {
      await prefs.setString('custom_background_url', customUrl);
    }
    if (mounted) {
      setState(() {
        _backgroundMode = mode;
        if (customUrl != null) {
          _customBackgroundUrl = customUrl;
        }
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
        title: dashboardStatsAsync.maybeWhen(
          data: (stats) => stats != null ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PsnAvatar(
                avatarUrl: stats.avatarUrl,
                isPsPlus: stats.displayPlatform == 'psn' ? stats.isPsPlus : false,
                size: 32,
                borderColor: CyberpunkTheme.neonCyan,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    stats.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    stats.displayPlatform.toUpperCase(),
                    style: TextStyle(
                      color: _getPlatformColor(stats.displayPlatform),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ) : const Text(
            'StatusXP',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          orElse: () => const Text(
            'StatusXP',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        centerTitle: false,
        actions: [
          if (kIsWeb) ...[
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () async {
                  // Default to Android link (can't detect platform without dart:html)
                  final url = Uri.parse('https://play.google.com/store/apps/details?id=com.statusxp.statusxp');
                  
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
            icon: const Icon(Icons.wallpaper_outlined),
            tooltip: 'Change Background',
            onPressed: () {
              _showBackgroundPicker(context);
            },
          ),
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
    final gamesAsync = ref.watch(unifiedGamesProvider);
    
    return Stack(
      children: [
        // Dynamic background from latest game with parallax
        Positioned.fill(
          child: Transform.translate(
            offset: Offset(0, -_scrollOffset * 0.5), // Move at half speed for parallax
            child: _buildDynamicBackground(gamesAsync),
          ),
        ),
        
        // Content overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.1),
                Colors.black.withOpacity(0.2),
                Colors.black.withOpacity(0.4),
              ],
            ),
          ),
          child: RefreshIndicator(
            onRefresh: () async {
              // Generate new shuffle seed on manual refresh
              if (_backgroundMode == 'shuffle') {
                setState(() {
                  _shuffleSeed = DateTime.now().millisecondsSinceEpoch;
                });
              }
              ref.refreshCoreData();
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // StatusXP large circle (center top) - animated entrance
                      SlideTransition(
                        position: _statusXPCircleSlide,
                        child: FadeTransition(
                          opacity: _statusXPCircleAnimation,
                          child: _buildStatusXPCircle(stats.totalStatusXP),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Platform circles row - animated entrance
                      SlideTransition(
                        position: _platformCirclesSlide,
                        child: FadeTransition(
                          opacity: _platformCirclesAnimation,
                          child: _buildPlatformCircles(stats),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // My Games Section with More dropdown
                      Row(
                        children: [
                          Text(
                            'MY GAMES',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              letterSpacing: 2.5,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          PopupMenuButton<String>(
                            onSelected: (String value) {
                              HapticFeedback.lightImpact();
                              context.push(value);
                            },
                            color: const Color(0xFF0A0E27),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: CyberpunkTheme.neonCyan.withOpacity(0.5), width: 1),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'More',
                                  style: TextStyle(
                                    color: CyberpunkTheme.neonCyan,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: CyberpunkTheme.neonCyan,
                                  size: 20,
                                ),
                              ],
                            ),
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                              const PopupMenuItem<String>(
                                value: '/games/browse',
                                child: Row(
                                  children: [
                                    Icon(Icons.explore, color: CyberpunkTheme.neonGreen, size: 20),
                                    SizedBox(width: 12),
                                    Text('Browse All Games', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: '/flex-room',
                                child: Row(
                                  children: [
                                    Icon(Icons.workspace_premium, color: CyberpunkTheme.goldNeon, size: 20),
                                    SizedBox(width: 12),
                                    Text('Flex Room', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              // TODO: Re-enable Analytics when premium feature is ready
                              // const PopupMenuItem<String>(
                              //   value: '/analytics',
                              //   child: Row(
                              //     children: [
                              //       Icon(Icons.analytics, color: CyberpunkTheme.neonPurple, size: 20),
                              //       SizedBox(width: 12),
                              //       Row(
                              //         children: [
                              //           Text('Analytics', style: TextStyle(color: Colors.white)),
                              //           SizedBox(width: 6),
                              //           Icon(Icons.workspace_premium, color: CyberpunkTheme.goldNeon, size: 14),
                              //         ],
                              //       ),
                              //     ],
                              //   ),
                              // ),
                              const PopupMenuItem<String>(
                                value: '/poster',
                                child: Row(
                                  children: [
                                    Icon(Icons.image, color: CyberpunkTheme.neonPink, size: 20),
                                    SizedBox(width: 12),
                                    Text('Status Poster', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: '/achievements',
                                child: Row(
                                  children: [
                                    Icon(Icons.stars, color: CyberpunkTheme.neonOrange, size: 20),
                                    SizedBox(width: 12),
                                    Text('Achievements', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: '/leaderboards',
                                child: Row(
                                  children: [
                                    Icon(Icons.leaderboard, color: CyberpunkTheme.neonGreen, size: 20),
                                    SizedBox(width: 12),
                                    Text('Leaderboards', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem<String>(
                                value: '/coop-partners',
                                child: Row(
                                  children: [
                                    Icon(Icons.group, color: CyberpunkTheme.neonCyan, size: 20),
                                    SizedBox(width: 12),
                                    Text('Co-op Partners', style: TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 18),
                      
                      // Embedded Games List
                      _buildEmbeddedGamesList(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicBackground(AsyncValue<List<UnifiedGame>> gamesAsync) {
    // Handle none mode - plain background
    if (_backgroundMode == 'none') {
      return Container(color: const Color(0xFF0A0E27));
    }
    
    // Handle custom background first
    if (_backgroundMode == 'custom' && _customBackgroundUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Custom image from device
          if (kIsWeb)
            Image.network(
              _customBackgroundUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0A0E27)),
            )
          else
            Image.file(
              File(_customBackgroundUrl!),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0A0E27)),
            ),
          // Blur effect
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ],
      );
    }
    
    return gamesAsync.when(
      loading: () => Container(color: const Color(0xFF0A0E27)),
      error: (_, __) => Container(color: const Color(0xFF0A0E27)),
      data: (games) {
        if (games.isEmpty) {
          return Container(color: const Color(0xFF0A0E27));
        }

        UnifiedGame? backgroundGame;
        
        // Determine which game to show based on mode
        if (_backgroundMode == 'shuffle') {
          // Random game using consistent seed (doesn't change on scroll)
          final random = (_shuffleSeed ?? 0) % games.length;
          backgroundGame = games[random];
        } else if (_backgroundMode == 'auto' || _backgroundMode == null) {
          // Most recent game (default)
          DateTime? latestTime;
          for (final game in games) {
            final gameTime = game.getMostRecentTrophyTime();
            if (gameTime != null) {
              if (latestTime == null || gameTime.isAfter(latestTime)) {
                latestTime = gameTime;
                backgroundGame = game;
              }
            }
          }
        } else {
          // Specific pinned game
          try {
            backgroundGame = games.firstWhere(
              (game) => game.title == _backgroundMode,
            );
          } catch (_) {
            // Pinned game not found, fall back to most recent
            DateTime? latestTime;
            for (final game in games) {
              final gameTime = game.getMostRecentTrophyTime();
              if (gameTime != null) {
                if (latestTime == null || gameTime.isAfter(latestTime)) {
                  latestTime = gameTime;
                  backgroundGame = game;
                }
              }
            }
          }
        }

        // Use cover art if available
        if (backgroundGame?.coverUrl != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                backgroundGame!.coverUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: const Color(0xFF0A0E27)),
              ),
              // Blur effect
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ],
          );
        }

        return Container(color: const Color(0xFF0A0E27));
      },
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
          Stack(
            children: [
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.7),
                  border: Border.all(color: CyberpunkTheme.neonPurple, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: CyberpunkTheme.neonPurple.withOpacity(0.6),
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
                    AnimatedBuilder(
                      animation: _statusXPAnimation,
                      builder: (context, child) {
                    final animatedValue = (totalStatusXP * _statusXPAnimation.value).toInt();
                    return Text(
                      _formatNumber(animatedValue),
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
                    );
                  },
                ),
              ],
            ),
          ),
          // Shimmer effect overlay
          Positioned.fill(
            child: _buildShimmer(size: 220),
          ),
        ],
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
          value: (stats.psnStats.platinums ?? 0).toString(),
          subtitle: '${stats.psnStats.gamesCount ?? 0} Games',
          bottomLabel:
              '${(stats.psnStats.averagePerGame ?? 0).toStringAsFixed(0)} AVG/GAME',
          color: const Color(0xFF00A8E1), // PlayStation Blue
        ),

        // Xbox Circle
        _buildPlatformCircle(
          label: 'Xbox Gamerscore',
          value: (stats.xboxStats.gamerscore ?? 0).toString(),
          subtitle: '${stats.xboxStats.gamesCount ?? 0} Games',
          bottomLabel:
              '${(stats.xboxStats.averagePerGame ?? 0).toStringAsFixed(0)} AVG/GAME',
          color: const Color(0xFF107C10), // Xbox Green
        ),

        // Steam Circle
        _buildPlatformCircle(
          label: 'Steam Achievs',
          value: (stats.steamStats.achievementsUnlocked ?? 0).toString(),
          subtitle: '${stats.steamStats.gamesCount ?? 0} Games',
          bottomLabel:
              '${(stats.steamStats.averagePerGame ?? 0).toStringAsFixed(0)} AVG/GAME',
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
        Stack(
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.7),
                border: Border.all(color: color, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.5),
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
              AnimatedBuilder(
                animation: _platformsAnimation,
                builder: (context, child) {
                  final numValue = int.tryParse(value.replaceAll(',', '')) ?? 0;
                  final animatedValue = (numValue * _platformsAnimation.value).toInt();
                  return Text(
                    _formatNumber(animatedValue),
                    style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      shadows: [
                        Shadow(color: color.withOpacity(0.6), blurRadius: 8),
                      ],
                    ),
                  );
                },
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
            // Shimmer effect overlay
            Positioned.fill(
              child: _buildShimmer(size: 110),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // AVG/GAME label below circle with shimmer
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: color.withOpacity(0.5), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
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
                  AnimatedBuilder(
                    animation: _platformsAnimation,
                    builder: (context, child) {
                      final numValue = int.tryParse(bottomLabel.split(' ')[0]) ?? 0;
                      final animatedValue = (numValue * _platformsAnimation.value).toInt();
                      return Text(
                        animatedValue.toString(),
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            // Shimmer effect on the box
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: AnimatedBuilder(
                  animation: _shimmerAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: [
                            _shimmerAnimation.value - 0.3,
                            _shimmerAnimation.value,
                            _shimmerAnimation.value + 0.3,
                          ],
                          colors: [
                            Colors.transparent,
                            Colors.white.withOpacity(0.15),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionsDropdown(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        PopupMenuButton<String>(
          onSelected: (String value) {
            HapticFeedback.lightImpact();
            context.push(value);
          },
          color: const Color(0xFF0A0E27),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: CyberpunkTheme.neonCyan.withOpacity(0.5), width: 1),
          ),
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: '/games/browse',
              child: Row(
                children: [
                  Icon(Icons.explore, color: CyberpunkTheme.neonGreen, size: 20),
                  SizedBox(width: 12),
                  Text('Browse All Games', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: '/poster',
              child: Row(
                children: [
                  Icon(Icons.image, color: CyberpunkTheme.neonPink, size: 20),
                  SizedBox(width: 12),
                  Text('Status Poster', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: '/flex-room',
              child: Row(
                children: [
                  Icon(Icons.emoji_events, color: CyberpunkTheme.neonPurple, size: 20),
                  SizedBox(width: 12),
                  Text('Flex Room', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: '/coop-partners',
              child: Row(
                children: [
                  Icon(Icons.handshake, color: CyberpunkTheme.neonOrange, size: 20),
                  SizedBox(width: 12),
                  Text('Find Co-op Partners', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: '/achievements',
              child: Row(
                children: [
                  Icon(Icons.stars, color: CyberpunkTheme.neonOrange, size: 20),
                  SizedBox(width: 12),
                  Text('Achievements', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: '/leaderboards',
              child: Row(
                children: [
                  Icon(Icons.leaderboard, color: CyberpunkTheme.neonCyan, size: 20),
                  SizedBox(width: 12),
                  Text('Leaderboards', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CyberpunkTheme.neonCyan.withOpacity(0.5), width: 1.5),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.more_horiz, color: CyberpunkTheme.neonCyan, size: 20),
                SizedBox(width: 8),
                Text(
                  'More',
                  style: TextStyle(
                    color: CyberpunkTheme.neonCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmbeddedGamesList(BuildContext context) {
    final gamesAsync = ref.watch(unifiedGamesProvider);

    return gamesAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading games: $error',
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
      data: (games) {
        if (games.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text(
                'No games yet. Sync your platforms to get started!',
                style: TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final displayGames = games.take(20).toList();

        return Column(
          children: [
            ...displayGames.map((game) => _buildGameCard(context, game)),
            if (games.length > 20)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    context.push('/unified-games');
                  },
                  child: Text(
                    'View All ${games.length} Games →',
                    style: const TextStyle(
                      color: CyberpunkTheme.neonCyan,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildGameCard(BuildContext context, UnifiedGame game) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF0A0E27).withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: CyberpunkTheme.neonCyan.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _handleGameTap(context, game),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: game.coverUrl != null
                    ? Image.network(
                        game.coverUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _buildPlaceholderCover(),
                      )
                    : _buildPlaceholderCover(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildPlatformPills(game),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.black38,
      child: const Icon(Icons.videogame_asset, color: Colors.white24, size: 40),
    );
  }

  Widget _buildPlatformPills(UnifiedGame game) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: game.platforms.map((platform) {
        return _buildPlatformPill(platform);
      }).toList(),
    );
  }

  Widget _buildPlatformPill(PlatformGameData platform) {
    Color color;
    String label;
    
    final platformLower = platform.platform.toLowerCase();
    final platformOriginal = platform.platform;
    
    if (platformLower.contains('ps') || platformLower == 'playstation') {
      color = const Color(0xFF00A8E1);
      if (platformOriginal.toUpperCase().contains('PS4')) {
        label = 'PS4';
      } else if (platformOriginal.toUpperCase().contains('PS5')) {
        label = 'PS5';
      } else if (platformOriginal.toUpperCase().contains('PS3')) {
        label = 'PS3';
      } else if (platformOriginal.toUpperCase().contains('VITA')) {
        label = 'PSVITA';
      } else {
        label = 'PS';
      }
    } else if (platformLower.contains('xbox')) {
      color = const Color(0xFF107C10);
      if (platformOriginal.toUpperCase().contains('360')) {
        label = 'X360';
      } else if (platformOriginal.toUpperCase().contains('ONE')) {
        label = 'XONE';
      } else if (platformOriginal.toUpperCase().contains('SERIES')) {
        label = 'XSX';
      } else {
        label = 'XBOX';
      }
    } else if (platformLower.contains('steam')) {
      color = const Color(0xFF66C0F4);
      label = 'Steam';
    } else {
      color = Colors.grey;
      label = platform.platform.toUpperCase();
    }

    final completion = platform.completion.toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '$label ${platform.achievementsEarned}/${platform.achievementsTotal} • $completion%',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _handleGameTap(BuildContext context, UnifiedGame game) {
    if (game.platforms.length == 1) {
      final platform = game.platforms.first;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => GameAchievementsScreen(
            platformId: platform.platformId,
            platformGameId: platform.platformGameId ?? platform.gameId,
            gameName: game.title,
            platform: platform.platform,
            coverUrl: game.coverUrl,
          ),
        ),
      );
    } else {
      _showPlatformSelectionDialog(context, game);
    }
  }

  void _showPlatformSelectionDialog(BuildContext context, UnifiedGame game) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xFF0A0E27),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: CyberpunkTheme.neonCyan, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Platform',
                  style: TextStyle(
                    color: CyberpunkTheme.neonCyan,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  game.title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                ...game.platforms.map((platform) {
                  Color platformColor;
                  IconData platformIcon;
                  String platformLabel;

                  final platformCode = platform.platform.toLowerCase();
                  if (platformCode.contains('ps') || platformCode == 'playstation') {
                    platformColor = const Color(0xFF0070CC);
                    platformIcon = Icons.sports_esports;
                    platformLabel = 'PlayStation';
                  } else if (platformCode.contains('xbox')) {
                    platformColor = const Color(0xFF107C10);
                    platformIcon = Icons.videogame_asset;
                    platformLabel = 'Xbox';
                  } else if (platformCode.contains('steam')) {
                    platformColor = const Color(0xFF1B2838);
                    platformIcon = Icons.store;
                    platformLabel = 'Steam';
                  } else {
                    platformColor = Colors.grey;
                    platformIcon = Icons.gamepad;
                    platformLabel = platform.platform;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => GameAchievementsScreen(
                              platformId: platform.platformId,
                              platformGameId: platform.platformGameId ?? platform.gameId,
                              gameName: game.title,
                              platform: platform.platform,
                              coverUrl: game.coverUrl,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: platformColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: platformColor, width: 2),
                        ),
                        child: Row(
                          children: [
                            Icon(platformIcon, color: platformColor, size: 32),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    platformLabel,
                                    style: TextStyle(
                                      color: platformColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${platform.achievementsEarned}/${platform.achievementsTotal} • ${platform.completion.toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, color: platformColor, size: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: CyberpunkTheme.neonCyan,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
  
  /// Shimmer effect overlay for circles
  Widget _buildShimmer({required double size}) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return ClipOval(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [
                  _shimmerAnimation.value - 0.3,
                  _shimmerAnimation.value,
                  _shimmerAnimation.value + 0.3,
                ],
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildModeButton({
    required IconData icon,
    required String label,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? CyberpunkTheme.neonPurple.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? CyberpunkTheme.neonPurple 
                : Colors.white.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: CyberpunkTheme.neonPurple.withOpacity(0.3),
              blurRadius: 8,
            ),
          ] : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? CyberpunkTheme.neonPurple : Colors.white70,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? CyberpunkTheme.neonPurple : Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _uploadCustomBackground(BuildContext context) async {
    // Check if user has premium
    final isPremium = await _subscriptionService.isPremiumActive();
    
    if (!isPremium) {
      // Show premium required dialog
      if (!context.mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1A1F3A),
          title: const Row(
            children: [
              Icon(Icons.star, color: CyberpunkTheme.goldNeon),
              SizedBox(width: 8),
              Text(
                'Premium Feature',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: const Text(
            'Custom background uploads are a Premium feature. Upgrade to Premium to use your own photos and screenshots as your dashboard background!',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/premium-subscription');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CyberpunkTheme.neonPurple,
              ),
              child: const Text('Upgrade to Premium'),
            ),
          ],
        ),
      );
      return;
    }
    
    // Premium user - proceed with image picker
    setState(() => _isUploadingCustom = true);
    
    try {
      final ImagePicker picker = ImagePicker();
      
      // Show bottom sheet for gallery vs camera
      if (!context.mounted) return;
      
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: const Color(0xFF0A0E27),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Image Source',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Optimal: 1080x1920 (9:16 portrait)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.photo_library, color: CyberpunkTheme.neonPurple),
                title: const Text('Gallery', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              if (!kIsWeb) // Camera only available on mobile
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: CyberpunkTheme.neonCyan),
                  title: const Text('Camera', style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
            ],
          ),
        ),
      );
      
      if (source == null) {
        setState(() => _isUploadingCustom = false);
        return;
      }
      
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      
      if (image == null) {
        setState(() => _isUploadingCustom = false);
        return;
      }
      
      // Save the image path locally
      await _setBackgroundMode('custom', customUrl: image.path);
      
      setState(() => _isUploadingCustom = false);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom background set successfully!'),
            backgroundColor: CyberpunkTheme.neonPurple,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploadingCustom = false);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _showBackgroundPicker(BuildContext context) {
    final gamesAsync = ref.read(unifiedGamesProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0E27),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return gamesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Error loading games')),
          data: (games) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.wallpaper, color: CyberpunkTheme.neonPurple),
                      SizedBox(width: 12),
                      Text(
                        'Choose Background',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _backgroundMode == 'none'
                        ? 'Plain background'
                        : _backgroundMode == 'custom'
                            ? 'Custom image selected'
                            : _backgroundMode == 'shuffle' 
                                ? 'Shuffling games randomly'
                                : _backgroundMode == 'auto' || _backgroundMode == null
                                    ? 'Showing most recent game'
                                    : 'Specific game selected',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Mode selection buttons - First row
                  Row(
                    children: [
                      Expanded(
                        child: _buildModeButton(
                          icon: Icons.block,
                          label: 'None',
                          description: 'Plain',
                          isSelected: _backgroundMode == 'none',
                          onTap: () {
                            _setBackgroundMode('none');
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildModeButton(
                          icon: Icons.history,
                          label: 'Auto',
                          description: 'Most Recent',
                          isSelected: _backgroundMode == 'auto' || _backgroundMode == null,
                          onTap: () {
                            _setBackgroundMode('auto');
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildModeButton(
                          icon: Icons.shuffle,
                          label: 'Shuffle',
                          description: 'Random',
                          isSelected: _backgroundMode == 'shuffle',
                          onTap: () {
                            _setBackgroundMode('shuffle');
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Second row with Custom button
                  Row(
                    children: [
                      Expanded(
                        child: _buildModeButton(
                          icon: Icons.add_photo_alternate,
                          label: 'Custom',
                          description: 'Upload ⭐',
                          isSelected: _backgroundMode == 'custom',
                          onTap: () async {
                            Navigator.pop(context);
                            await _uploadCustomBackground(context);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()),
                      const SizedBox(width: 12),
                      const Expanded(child: SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Or pick a specific game:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: games.length,
                      itemBuilder: (context, index) {
                        final game = games[index];
                        final isSelected = game.title == _backgroundMode;
                        
                        return GestureDetector(
                          onTap: () {
                            _setBackgroundMode(game.title);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected 
                                    ? CyberpunkTheme.neonPurple 
                                    : Colors.white.withOpacity(0.2),
                                width: isSelected ? 3 : 1,
                              ),
                              boxShadow: isSelected ? [
                                BoxShadow(
                                  color: CyberpunkTheme.neonPurple.withOpacity(0.5),
                                  blurRadius: 12,
                                ),
                              ] : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (game.coverUrl != null)
                                    Image.network(
                                      game.coverUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey.shade900,
                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    )
                                  else
                                    Container(
                                      color: Colors.grey.shade900,
                                      child: const Icon(Icons.videogame_asset, color: Colors.grey),
                                    ),
                                  if (isSelected)
                                    Container(
                                      color: CyberpunkTheme.neonPurple.withOpacity(0.3),
                                      child: const Center(
                                        child: Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                          size: 40,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
