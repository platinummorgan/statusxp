import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Status Poster Screen
/// 
/// Displays a shareable visual card showcasing gaming achievements.
/// This is a preview/placeholder for the future export functionality.
class StatusPosterScreen extends ConsumerStatefulWidget {
  const StatusPosterScreen({super.key});

  @override
  ConsumerState<StatusPosterScreen> createState() => _StatusPosterScreenState();
}

class _StatusPosterScreenState extends ConsumerState<StatusPosterScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  int? _globalRank;
  double? _percentile;
  bool _isLoadingRank = true;

  @override
  void initState() {
    super.initState();
    _loadGlobalRank();
  }

  Future<void> _loadGlobalRank() async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('leaderboard_global_cache')
          .select('rank')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _globalRank = response['rank'] as int?;
          _isLoadingRank = false;
        });

        // Calculate percentile
        if (_globalRank != null) {
          final totalUsers = await supabase
              .from('leaderboard_global_cache')
              .select('user_id', const FetchOptions(count: CountOption.exact));
          final total = totalUsers.count;
          if (total > 0) {
            _percentile = ((_globalRank! / total) * 100);
            if (mounted) setState(() {});
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRank = false);
      }
    }
  }

  Future<void> _sharePoster() async {
    HapticFeedback.lightImpact();
    try {
      final bytes = await _screenshotController.capture();
      if (bytes == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not capture poster')),
          );
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/statusxp_poster.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'My gaming status on StatusXP 🎮',
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to share poster')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);
    final userStatsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Status Poster'),
        leading: BackButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            context.pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _sharePoster,
          ),
        ],
      ),
      body: dashboardStatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading stats: $error'),
        ),
        data: (dashboardStats) {
          if (dashboardStats == null) {
            return const Center(child: Text('No stats available'));
          }
          return userStatsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Text('Error loading highlights: $error'),
            ),
            data: (userStats) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                backgroundDark,
                surfaceDark,
                accentPrimary.withValues(alpha: 0.1),
              ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                  ),
                  child: Screenshot(
                    controller: _screenshotController,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF0A0E27),
                            const Color(0xFF1A1F3A),
                            CyberpunkTheme.neonPurple.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: CyberpunkTheme.neonPurple.withValues(alpha: 0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: CyberpunkTheme.neonPurple.withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: 0,
                          ),
                          BoxShadow(
                            color: CyberpunkTheme.neonCyan.withValues(alpha: 0.2),
                            blurRadius: 60,
                            spreadRadius: -10,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header with glow
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: CyberpunkTheme.neonCyan.withValues(alpha: 0.3),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'STATUS//XP',
                              style: theme.textTheme.labelSmall?.copyWith(
                                letterSpacing: 3,
                                color: CyberpunkTheme.neonCyan,
                                fontWeight: FontWeight.w600,
                                shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonCyan),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Username with massive glow
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              dashboardStats.displayName.toUpperCase(),
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 48,
                                letterSpacing: 2,
                                shadows: [
                                  ...CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonPurple, blurRadius: 20),
                                  Shadow(
                                    color: CyberpunkTheme.neonPurple.withValues(alpha: 0.5),
                                    blurRadius: 40,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Massive StatusXP display
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  CyberpunkTheme.neonPurple.withValues(alpha: 0.15),
                                  CyberpunkTheme.neonPurple.withValues(alpha: 0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: CyberpunkTheme.neonPurple.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  _formatNumber(dashboardStats.totalStatusXP.toInt()),
                                  style: theme.textTheme.displayLarge?.copyWith(
                                    color: CyberpunkTheme.neonPurple,
                                    fontSize: 67,
                                    fontWeight: FontWeight.w900,
                                    height: 0.9,
                                    letterSpacing: -1,
                                    shadows: [
                                      ...CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonPurple, blurRadius: 16),
                                      Shadow(
                                        color: CyberpunkTheme.neonPurple.withValues(alpha: 0.6),
                                        blurRadius: 30,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'STATUS POINTS',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: CyberpunkTheme.neonPurple.withValues(alpha: 0.8),
                                    letterSpacing: 4,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Platform stats grid
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _PlatformStat(
                                label: 'PSN',
                                games: dashboardStats.psnStats.gamesCount,
                                achievements: dashboardStats.psnStats.achievementsUnlocked,
                                achievementLabel: 'TROPH',
                                color: CyberpunkTheme.neonCyan,
                              ),
                              _PlatformStat(
                                label: 'XBOX',
                                games: dashboardStats.xboxStats.gamesCount,
                                achievements: dashboardStats.xboxStats.gamerscore,
                                achievementLabel: 'GAMER',
                                color: CyberpunkTheme.neonGreen,
                              ),
                              _PlatformStat(
                                label: 'STEAM',
                                games: dashboardStats.steamStats.gamesCount,
                                achievements: dashboardStats.steamStats.achievementsUnlocked,
                                achievementLabel: 'ACHV',
                                color: accentSecondary,
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Rank & Percentile badges
                          if (_globalRank != null || _percentile != null)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_globalRank != null) ...[                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          CyberpunkTheme.neonCyan.withValues(alpha: 0.2),
                                          CyberpunkTheme.neonCyan.withValues(alpha: 0.05),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: CyberpunkTheme.neonCyan.withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.emoji_events,
                                          size: 16,
                                          color: CyberpunkTheme.neonCyan,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'RANK #${_formatNumber(_globalRank!)}',
                                          style: theme.textTheme.labelMedium?.copyWith(
                                            color: CyberpunkTheme.neonCyan,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.5,
                                            shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonCyan),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_percentile != null) const SizedBox(width: 12),
                                ],
                                if (_percentile != null && _percentile! <= 25)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          CyberpunkTheme.goldNeon.withValues(alpha: 0.2),
                                          CyberpunkTheme.goldNeon.withValues(alpha: 0.05),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: CyberpunkTheme.goldNeon.withValues(alpha: 0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Text(
                                      'TOP ${_percentile!.toStringAsFixed(0)}%',
                                      style: theme.textTheme.labelMedium?.copyWith(
                                        color: CyberpunkTheme.goldNeon,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                        shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.goldNeon),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          if (_globalRank != null || _percentile != null)
                            const SizedBox(height: 16),

                          // Call to action
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: CyberpunkTheme.neonPink.withValues(alpha: 0.3),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '⚡ BEAT MY SCORE',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: CyberpunkTheme.neonPink,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Neon divider
                          Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  CyberpunkTheme.neonPurple.withValues(alpha: 0.5),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 28),

                          // Elite Achievements Section - only show if data exists
                          if (userStats.rarestTrophyName != 'None' || userStats.hardestPlatGame != 'None') ...[
                            Text(
                              '⚡ ELITE ACHIEVEMENTS',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: CyberpunkTheme.neonOrange,
                                letterSpacing: 3,
                                fontWeight: FontWeight.w700,
                                shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonOrange),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                          ],

                          // Rarest Trophy - Featured
                          if (userStats.rarestTrophyName != 'None') ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    CyberpunkTheme.neonPink.withValues(alpha: 0.1),
                                    CyberpunkTheme.neonPurple.withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CyberpunkTheme.neonPink.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.stars,
                                        color: CyberpunkTheme.neonPink,
                                        size: 20,
                                        shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonPink),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'RAREST TROPHY',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: CyberpunkTheme.neonPink.withValues(alpha: 0.9),
                                          letterSpacing: 2,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    userStats.rarestTrophyName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: CyberpunkTheme.neonPink.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${userStats.rarestTrophyRarity}% RARITY',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: CyberpunkTheme.neonPink,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Hardest Platinum
                          if (userStats.hardestPlatGame != 'None') ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    CyberpunkTheme.neonOrange.withValues(alpha: 0.1),
                                    CyberpunkTheme.goldNeon.withValues(alpha: 0.05),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: CyberpunkTheme.neonOrange.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.emoji_events,
                                    color: CyberpunkTheme.neonOrange,
                                    size: 28,
                                    shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonOrange),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'HARDEST PLATINUM',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: CyberpunkTheme.neonOrange.withValues(alpha: 0.9),
                                            letterSpacing: 1.5,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          userStats.hardestPlatGame,
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          const SizedBox(height: 20),

                          // Footer with QR code and info
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: CyberpunkTheme.neonCyan.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Left: App info and timestamp
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'STATUSXP',
                                        style: theme.textTheme.labelLarge?.copyWith(
                                          color: CyberpunkTheme.neonCyan,
                                          letterSpacing: 3,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonCyan, blurRadius: 8),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Cross-Platform Gaming Tracker',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: Colors.white.withValues(alpha: 0.6),
                                          fontSize: 9,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Updated ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: CyberpunkTheme.neonCyan.withValues(alpha: 0.5),
                                          fontSize: 8,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Right: QR Code
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: CyberpunkTheme.neonCyan.withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: QrImageView(
                                    data: 'https://play.google.com/store/apps/details?id=com.statusxp.statusxp',
                                    version: QrVersions.auto,
                                    size: 80,
                                    backgroundColor: Colors.white,
                                    eyeStyle: const QrEyeStyle(
                                      eyeShape: QrEyeShape.square,
                                      color: Colors.black,
                                    ),
                                    dataModuleStyle: const QrDataModuleStyle(
                                      dataModuleShape: QrDataModuleShape.square,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
        ),
          ),
        );
        },
      ),
    );
  }

  /// Format large numbers with commas
  String _formatNumber(int number) {
    final str = number.toString();
    if (str.length <= 3) return str;
    
    final buffer = StringBuffer();
    var count = 0;
    for (var i = str.length - 1; i >= 0; i--) {
      if (count == 3) {
        buffer.write(',');
        count = 0;
      }
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }
}

/// Platform stat widget for Status Poster
class _PlatformStat extends StatelessWidget {
  final String label;
  final int games;
  final int achievements;
  final String achievementLabel;
  final Color color;

  const _PlatformStat({
    required this.label,
    required this.games,
    required this.achievements,
    required this.achievementLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.1),
            color.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              shadows: CyberpunkTheme.neonGlow(color: color, blurRadius: 6),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$games',
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              height: 1.0,
              shadows: CyberpunkTheme.neonGlow(color: color, blurRadius: 8),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'GAMES',
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.6),
              fontSize: 9,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            width: 30,
            color: color.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            '$achievements',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color.withValues(alpha: 0.9),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            achievementLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.5),
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
