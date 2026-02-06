import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/data/repositories/leaderboard_repository.dart';
import 'package:statusxp/domain/leaderboard_entry.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/screens/flex_room_screen.dart';

/// Leaderboard type enum
enum LeaderboardType {
  statusXP,
  platinums,
  xboxAchievements,
  steamAchievements,
}

/// Leaderboard Screen - Shows global rankings across all metrics
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  LeaderboardType _selectedType = LeaderboardType.statusXP;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedType = LeaderboardType.values[_tabController.index];
        });
        // Refresh on tab change for fresh data
        ref.invalidate(leaderboardProvider(_selectedType));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final leaderboardAsync = ref.watch(
      leaderboardProvider(_selectedType),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboards', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A0E27),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: const Color(0xFF0A0E27),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              indicatorColor: CyberpunkTheme.neonPurple,
              labelColor: CyberpunkTheme.neonPurple,
              unselectedLabelColor: Colors.white.withOpacity(0.5),
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
              tabs: const [
                Tab(text: 'StatusXP'),
                Tab(text: 'Platinums'),
                Tab(text: 'Xbox'),
                Tab(text: 'Steam'),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildLeaderboardContent(
              leaderboardAsync,
              LeaderboardType.statusXP,
              'Total StatusXP',
              CyberpunkTheme.neonPurple,
            ),
            _buildLeaderboardContent(
              leaderboardAsync,
              LeaderboardType.platinums,
              'Platinum Trophies',
              const Color(0xFF00A8E1),
            ),
            _buildLeaderboardContent(
              leaderboardAsync,
              LeaderboardType.xboxAchievements,
              'Xbox Achievements',
              const Color(0xFF107C10),
            ),
            _buildLeaderboardContent(
              leaderboardAsync,
              LeaderboardType.steamAchievements,
              'Steam Achievements',
              const Color(0xFF66C0F4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardContent(
    AsyncValue<List<LeaderboardEntry>> leaderboardAsync,
    LeaderboardType type,
    String subtitle,
    Color accentColor,
  ) {
    return leaderboardAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading leaderboard: $error'),
          ],
        ),
      ),
      data: (entries) {
        if (entries.isEmpty) {
          return Center(
            child: Text(
              'No rankings available yet',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(leaderboardProvider(_selectedType));
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final rank = index + 1;
              
              return _buildLeaderboardCard(
                entry,
                rank,
                type,
                accentColor,
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildLeaderboardCard(
    LeaderboardEntry entry,
    int rank,
    LeaderboardType type,
    Color accentColor,
  ) {
    // Determine medal color for top 3
    Color? medalColor;
    IconData? medalIcon;
    
    if (rank == 1) {
      medalColor = const Color(0xFFFFD700); // Gold
      medalIcon = Icons.workspace_premium;
    } else if (rank == 2) {
      medalColor = const Color(0xFFC0C0C0); // Silver
      medalIcon = Icons.workspace_premium;
    } else if (rank == 3) {
      medalColor = const Color(0xFFCD7F32); // Bronze
      medalIcon = Icons.workspace_premium;
    }

    // Get current user ID to highlight their entry
    final currentUserId = ref.read(currentUserIdProvider);
    final isCurrentUser = entry.userId == currentUserId;

    return InkWell(
      onTap: () {
        // Navigate to user's Flex Room
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FlexRoomScreen(viewerId: entry.userId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? accentColor.withOpacity(0.15)
              : const Color(0xFF0A0E27).withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrentUser
                ? accentColor
                : medalColor ?? accentColor.withOpacity(0.3),
            width: isCurrentUser ? 2 : 1,
          ),
          boxShadow: isCurrentUser
              ? [
                  BoxShadow(
                    color: accentColor.withOpacity(0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
          children: [
            // Rank number or medal with ordinal text
            SizedBox(
              width: 60,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (medalIcon != null)
                    Icon(
                      medalIcon,
                      color: medalColor,
                      size: 36,
                      shadows: [
                        Shadow(
                          color: medalColor!.withOpacity(0.6),
                          blurRadius: 8,
                        ),
                      ],
                    )
                  else
                    Text(
                      '#$rank',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    _getOrdinal(rank),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: medalColor ?? Colors.white.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Rank movement indicator (show for all leaderboards)
                  _buildRankMovementIndicator(entry),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundImage: entry.avatarUrl != null
                  ? NetworkImage(entry.avatarUrl!)
                  : null,
              backgroundColor: accentColor.withOpacity(0.3),
              child: entry.avatarUrl == null
                  ? Icon(Icons.person, color: accentColor, size: 24)
                  : null,
            ),

            const SizedBox(width: 12),

            // User info and score - restructured for longer names
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Full name with YOU badge
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            shadows: isCurrentUser
                                ? [
                                    Shadow(
                                      color: accentColor.withOpacity(0.6),
                                      blurRadius: 4,
                                    ),
                                  ]
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: accentColor,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'YOU',
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Bottom row: Custom display for PSN, Xbox, Steam, StatusXP
                  if (type == LeaderboardType.platinums)
                    Row(
                      children: [
                        Flexible(
                          child: _buildPSNTrophyRow(entry, accentColor),
                        ),
                      ],
                    )
                  else if (type == LeaderboardType.xboxAchievements)
                    _buildXboxGamerscoreRow(entry, accentColor)
                  else if (type == LeaderboardType.steamAchievements)
                    _buildSteamAchievementsRow(entry, accentColor)
                  else if (type == LeaderboardType.statusXP)
                    _buildStatusXPRow(entry, accentColor)
                  else
                    _buildGenericScoreRow(entry, type, accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );  // Close InkWell
  }

  String _getSubtitle(LeaderboardEntry entry, LeaderboardType type) {
    switch (type) {
      case LeaderboardType.statusXP:
        // Show current | potential StatusXP (compact)
        if (entry.potentialScore != null && entry.potentialScore! > 0) {
          return '${_formatCompact(entry.score)} | ${_formatCompact(entry.potentialScore!)} XP';
        }
        return '${entry.gamesCount} games';
      case LeaderboardType.platinums:
        // Show trophy breakdown: P | G | S | B (very compact)
        if (entry.platinumCount != null && entry.goldCount != null) {
          return '${entry.platinumCount} | ${entry.goldCount} | ${entry.silverCount} | ${entry.bronzeCount}';
        }
        return '${entry.gamesCount} games';
      case LeaderboardType.xboxAchievements:
        // Show current | potential gamerscore (compact)
        if (entry.potentialScore != null && entry.potentialScore! > 0) {
          return '${_formatCompact(entry.score)} | ${_formatCompact(entry.potentialScore!)} GS';
        }
        return '${entry.gamesCount} games';
      case LeaderboardType.steamAchievements:
        // Show current | potential achievements (compact)
        if (entry.potentialScore != null && entry.potentialScore! > 0) {
          return '${_formatCompact(entry.score)} | ${_formatCompact(entry.potentialScore!)}';
        }
        return '${entry.gamesCount} games';
    }
  }

  String _formatCompact(int number) {
    if (number >= 1000000) {
      final millions = number / 1000000;
      return millions >= 10 ? '${millions.toStringAsFixed(0)}M' : '${millions.toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      final thousands = number / 1000;
      return thousands >= 10 ? '${thousands.toStringAsFixed(0)}k' : '${thousands.toStringAsFixed(1)}k';
    }
    return number.toString();
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      return NumberFormat('#,###').format(number);
    }
    return number.toString();
  }

  String _getScoreLabel(LeaderboardType type) {
    switch (type) {
      case LeaderboardType.statusXP:
        return 'XP';
      case LeaderboardType.platinums:
        return 'Platinums';
      case LeaderboardType.xboxAchievements:
        return 'Gamerscore';
      case LeaderboardType.steamAchievements:
        return 'Achievements';
    }
  }

  String _formatScore(int score, LeaderboardType type) {
    // Use abbreviated format for all leaderboards
    if (score >= 1000000) {
      return '${(score / 1000000).toStringAsFixed(1)}M';
    } else if (score >= 1000) {
      return '${(score / 1000).toStringAsFixed(1)}k';
    }
    return score.toString();
  }

  String _getOrdinal(int rank) {
    if (rank % 100 >= 11 && rank % 100 <= 13) {
      return '${rank}th';
    }
    switch (rank % 10) {
      case 1:
        return '${rank}st';
      case 2:
        return '${rank}nd';
      case 3:
        return '${rank}rd';
      default:
        return '${rank}th';
    }
  }

  Widget _buildRankMovementIndicator(LeaderboardEntry entry) {
    if (entry.isNew) {
      return Container(
        margin: const EdgeInsets.only(top: 3),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF00A8E1).withOpacity(0.25),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: const Color(0xFF00A8E1),
            width: 1.5,
          ),
        ),
        child: const Text(
          'NEW',
          style: TextStyle(
            color: Color(0xFF00A8E1),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      );
    }

    if (entry.rankChange == 0) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        child: Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      );
    }

    final bool isUp = entry.rankChange > 0;
    final color = isUp ? const Color(0xFF00FF41) : const Color(0xFFFF0040);
    final icon = isUp ? Icons.arrow_upward : Icons.arrow_downward;

    return Container(
      margin: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 12,
          ),
          const SizedBox(width: 2),
          Text(
            '${entry.rankChange.abs()}',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: color.withOpacity(0.6),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPSNTrophyRow(LeaderboardEntry entry, Color accentColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Earned trophies
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTrophyCount('assets/images/platinum_trophy.png', entry.platinumCount ?? 0, isLarge: true, color: accentColor),
            const SizedBox(width: 6),
            _buildTrophyCount('assets/images/gold_trophy.png', entry.goldCount ?? 0),
            const SizedBox(width: 4),
            _buildTrophyCount('assets/images/silver_trophy.png', entry.silverCount ?? 0),
            const SizedBox(width: 4),
            _buildTrophyCount('assets/images/bronze_trophy.png', entry.bronzeCount ?? 0),
          ],
        ),
        // Possible trophies keynote
        if (entry.possiblePlatinum != null || entry.possibleGold != null || entry.possibleSilver != null || entry.possibleBronze != null) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Owned: ',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                '${entry.possiblePlatinum ?? 0} | ${entry.possibleGold ?? 0} | ${entry.possibleSilver ?? 0} | ${entry.possibleBronze ?? 0}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildXboxGamerscoreRow(LeaderboardEntry entry, Color accentColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/gamerscore_img.png',
          width: 44,
          height: 44,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.emoji_events,
              size: 44,
              color: accentColor.withOpacity(0.6),
            );
          },
        ),
        const SizedBox(width: 6),
        Text(
          _formatNumber(entry.score),
          style: TextStyle(
            color: accentColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: accentColor.withOpacity(0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '|',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          entry.potentialScore != null && entry.potentialScore! > 0
              ? _formatNumber(entry.potentialScore!)
              : '0',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSteamAchievementsRow(LeaderboardEntry entry, Color accentColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/steam_img.png',
          width: 44,
          height: 44,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.emoji_events,
              size: 44,
              color: accentColor.withOpacity(0.6),
            );
          },
        ),
        const SizedBox(width: 6),
        Text(
          _formatNumber(entry.score),
          style: TextStyle(
            color: accentColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: accentColor.withOpacity(0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '|',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          entry.potentialScore != null && entry.potentialScore! > 0
              ? _formatNumber(entry.potentialScore!)
              : '0',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusXPRow(LeaderboardEntry entry, Color accentColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/statusxp_img.png',
          width: 44,
          height: 44,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.emoji_events,
              size: 44,
              color: accentColor.withOpacity(0.6),
            );
          },
        ),
        const SizedBox(width: 6),
        Text(
          _formatNumber(entry.score),
          style: TextStyle(
            color: accentColor,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(
                color: accentColor.withOpacity(0.6),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(width: 3),
        Text(
          '|',
          style: TextStyle(
            color: Colors.white.withOpacity(0.3),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          entry.potentialScore != null && entry.potentialScore! > 0
              ? _formatNumber(entry.potentialScore!)
              : '0',
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildGenericScoreRow(LeaderboardEntry entry, LeaderboardType type, Color accentColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            _getSubtitle(entry, type),
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatScore(entry.score, type),
              style: TextStyle(
                color: accentColor,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: accentColor.withOpacity(0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                _getScoreLabel(type),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrophyCount(String assetPath, int count, {bool isLarge = false, Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          assetPath,
          width: isLarge ? 20 : 12,
          height: isLarge ? 20 : 12,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              Icons.emoji_events,
              size: isLarge ? 20 : 12,
              color: Colors.white.withOpacity(0.3),
            );
          },
        ),
        const SizedBox(width: 2),
        Text(
          count.toString(),
          style: TextStyle(
            color: color ?? Colors.white.withOpacity(isLarge ? 0.8 : 0.5),
            fontSize: isLarge ? 18 : 9,
            fontWeight: isLarge ? FontWeight.w900 : FontWeight.w500,
            shadows: isLarge && color != null ? [
              Shadow(
                color: color.withOpacity(0.6),
                blurRadius: 6,
              ),
            ] : null,
          ),
        ),
      ],
    );
  }}