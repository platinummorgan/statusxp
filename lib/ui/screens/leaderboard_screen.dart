import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
                mainAxisSize: MainAxisSize.min,
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
                  // Bottom row: Games count on left, score + label on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _getSubtitle(entry, type),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
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
                  ),
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
        return '${entry.gamesCount} games';
      case LeaderboardType.platinums:
        return '${entry.gamesCount} games';
      case LeaderboardType.xboxAchievements:
      case LeaderboardType.steamAchievements:
        return '${entry.gamesCount} games';
    }
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
}
