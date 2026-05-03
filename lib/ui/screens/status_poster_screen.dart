import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'package:statusxp/domain/dashboard_stats.dart';
import 'package:statusxp/domain/user_stats.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';

import 'package:statusxp/utils/statusxp_logger.dart';

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

  Future<void> _sharePoster() async {
    HapticFeedback.lightImpact();
    try {
      final bytes = await _screenshotController.capture();
      if (!mounted) return;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not capture poster')),
        );
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/statusxp_poster.png');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'My gaming status on StatusXP 🎮');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to share poster')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dashboardStatsAsync = ref.watch(dashboardStatsProvider);
    final userStatsAsync = ref.watch(userStatsProvider);
    final ranksAsync = ref.watch(leaderboardRanksProvider);

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
          IconButton(icon: const Icon(Icons.share), onPressed: _sharePoster),
        ],
      ),
      body: dashboardStatsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) =>
            Center(child: Text('Error loading stats: $error')),
        data: (dashboardStats) {
          if (dashboardStats == null) {
            return const Center(child: Text('No stats available'));
          }
          Widget buildPoster(UserStats userStats) {
            return ranksAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) {
                statusxpLog('Error loading ranks: $error');
                // Continue with null ranks if there's an error
                return _buildPosterContent(
                  context,
                  theme,
                  dashboardStats,
                  userStats,
                  null,
                );
              },
              data: (ranks) => _buildPosterContent(
                context,
                theme,
                dashboardStats,
                userStats,
                ranks,
              ),
            );
          }

          return userStatsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) {
              if (_isRecoverableStatsError(error)) {
                statusxpLog(
                  'Status Poster: falling back to lightweight user stats due to error: $error',
                );
                return buildPoster(_fallbackUserStats(dashboardStats));
              }
              return Center(child: Text('Error loading user stats: $error'));
            },
            data: buildPoster,
          );
        },
      ),
    );
  }

  bool _isRecoverableStatsError(Object error) {
    final message = error.toString();
    return message.contains('statement timeout') ||
        message.contains('57014') ||
        message.contains('SocketException') ||
        message.contains('Failed host lookup') ||
        message.contains('AuthRetryableFetchException');
  }

  UserStats _fallbackUserStats(DashboardStats dashboardStats) {
    final psn = dashboardStats.psnStats;
    return UserStats(
      username: dashboardStats.displayName,
      avatarUrl: null,
      isPsPlus: false,
      totalPlatinums: psn.platinums,
      totalGamesTracked: psn.gamesCount,
      totalTrophies: psn.achievementsUnlocked,
      bronzeTrophies: 0,
      silverTrophies: 0,
      goldTrophies: 0,
      platinumTrophies: psn.platinums,
      hardestPlatGame: 'None',
      rarestTrophyName: 'None',
      rarestTrophyRarity: 0.0,
    );
  }

  Widget _buildPosterContent(
    BuildContext context,
    ThemeData theme,
    DashboardStats dashboardStats,
    UserStats userStats,
    Map<String, int?>? ranks,
  ) {
    return Container(
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
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            const outerPadding = 12.0;
            final maxWidth = constraints.maxWidth - (outerPadding * 2);
            final maxHeight = constraints.maxHeight - (outerPadding * 2);
            final posterWidth = math.min(maxWidth, maxHeight * (9 / 16));
            final posterHeight = posterWidth * (16 / 9);
            final globalRank = ranks?['global'];
            final eliteParts = <String>[];

            if (userStats.rarestTrophyName != 'None') {
              eliteParts.add(
                'Rarest: ${userStats.rarestTrophyName} (${userStats.rarestTrophyRarity.toStringAsFixed(2)}%)',
              );
            }
            if (userStats.hardestPlatGame != 'None') {
              eliteParts.add('Hardest Plat: ${userStats.hardestPlatGame}');
            }
            final eliteSummary = eliteParts.isEmpty
                ? 'Sync complete. Keep climbing your ranks.'
                : eliteParts.join('  •  ');

            return Center(
              child: SizedBox(
                width: posterWidth,
                height: posterHeight,
                child: Screenshot(
                  controller: _screenshotController,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFF050815), Color(0xFF111A3A)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: CyberpunkTheme.neonPurple.withValues(alpha: 0.45),
                        width: 2.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: CyberpunkTheme.neonPurple.withValues(alpha: 0.3),
                          blurRadius: 40,
                        ),
                        BoxShadow(
                          color: CyberpunkTheme.neonCyan.withValues(alpha: 0.18),
                          blurRadius: 55,
                          spreadRadius: -8,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -80,
                          right: -50,
                          child: Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  CyberpunkTheme.neonPurple.withValues(
                                    alpha: 0.35,
                                  ),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -60,
                          left: -40,
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  CyberpunkTheme.neonCyan.withValues(alpha: 0.24),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: CyberpunkTheme.neonCyan
                                            .withValues(alpha: 0.6),
                                        width: 1.4,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.asset(
                                        'assets/images/app_icon.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'STATUS POSTER',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                color: CyberpunkTheme.neonCyan,
                                                letterSpacing: 1.8,
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          dashboardStats.displayName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                shadows: CyberpunkTheme.neonGlow(
                                                  color:
                                                      CyberpunkTheme.neonPurple,
                                                  blurRadius: 8,
                                                ),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (globalRank != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CyberpunkTheme.neonPurple
                                            .withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: CyberpunkTheme.neonPurple
                                              .withValues(alpha: 0.55),
                                        ),
                                      ),
                                      child: Text(
                                        '#${_formatNumber(globalRank)}',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              color: CyberpunkTheme.neonPurple,
                                              fontWeight: FontWeight.w900,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      CyberpunkTheme.neonPurple.withValues(
                                        alpha: 0.23,
                                      ),
                                      CyberpunkTheme.neonPink.withValues(
                                        alpha: 0.1,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: CyberpunkTheme.neonPurple.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _formatNumber(
                                        dashboardStats.totalStatusXP.toInt(),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.displaySmall?.copyWith(
                                            color: CyberpunkTheme.neonPurple,
                                            fontSize: 52,
                                            fontWeight: FontWeight.w900,
                                            height: 0.9,
                                            shadows: CyberpunkTheme.neonGlow(
                                              color: CyberpunkTheme.neonPurple,
                                              blurRadius: 14,
                                            ),
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'STATUSXP',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: Colors.white.withValues(
                                              alpha: 0.82,
                                            ),
                                            letterSpacing: 3,
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _PosterPlatformTile(
                                      label: 'PSN',
                                      primaryValue:
                                          dashboardStats.psnStats.platinums,
                                      primaryLabel: 'PLAT',
                                      secondaryValue:
                                          dashboardStats.psnStats.gamesCount,
                                      secondaryLabel: 'GAMES',
                                      rank: ranks?['psn'],
                                      color: CyberpunkTheme.neonCyan,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _PosterPlatformTile(
                                      label: 'XBOX',
                                      primaryValue:
                                          dashboardStats.xboxStats.gamerscore,
                                      primaryLabel: 'GS',
                                      secondaryValue:
                                          dashboardStats.xboxStats.gamesCount,
                                      secondaryLabel: 'GAMES',
                                      rank: ranks?['xbox'],
                                      color: CyberpunkTheme.neonGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _PosterPlatformTile(
                                      label: 'STEAM',
                                      primaryValue: dashboardStats
                                          .steamStats
                                          .achievementsUnlocked,
                                      primaryLabel: 'ACHV',
                                      secondaryValue:
                                          dashboardStats.steamStats.gamesCount,
                                      secondaryLabel: 'GAMES',
                                      rank: ranks?['steam'],
                                      color: accentSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: CyberpunkTheme.neonOrange.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.auto_awesome,
                                      color: CyberpunkTheme.neonOrange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        eliteSummary,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.9,
                                              ),
                                              height: 1.2,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.only(top: 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(
                                      color: Colors.white.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'What\'s Your Status!?',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  color:
                                                      CyberpunkTheme.neonPink,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.5,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Updated ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: Colors.white70,
                                                  fontSize: 11,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: QrImageView(
                                        data: 'https://statusxp.com',
                                        version: QrVersions.auto,
                                        size: 58,
                                        backgroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
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
            );
          },
        ),
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
class _PosterPlatformTile extends StatelessWidget {
  final String label;
  final int primaryValue;
  final String primaryLabel;
  final int secondaryValue;
  final String secondaryLabel;
  final Color color;
  final int? rank;

  const _PosterPlatformTile({
    required this.label,
    required this.primaryValue,
    required this.primaryLabel,
    required this.secondaryValue,
    required this.secondaryLabel,
    required this.color,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Text(
                  _compact(primaryValue),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  primaryLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: color,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$secondaryValue $secondaryLabel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
          if (rank != null) ...[
            const SizedBox(height: 5),
            Text(
              'Rank #$rank',
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toString();
  }
}
