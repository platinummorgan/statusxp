import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/domain/trophy_room_data.dart';
import 'package:statusxp/domain/user_stats.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/widgets/glass_panel.dart';
import 'package:statusxp/ui/widgets/neon_action_chip.dart';
import 'package:statusxp/ui/widgets/psn_avatar.dart';

// ============================================================================
// TODO: ORIGINAL TROPHY ROOM SCREEN
// ============================================================================
// This screen can be repurposed for:
// - Stats-only dashboard showing achievements overview
// - Trophy analytics and progression tracking
// - Or deleted if functionality is fully replaced
// ============================================================================

/// Trophy Room Screen - Showcase of achievements and flex moments
/// 
/// Displays featured platinums, ultra-rare trophies, and recent unlocks
/// in a cyberpunk-themed showcase gallery
class TrophyRoomScreen extends ConsumerWidget {
  const TrophyRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trophyRoomAsync = ref.watch(trophyRoomDataProvider);
    final userStatsAsync = ref.watch(userStatsProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'TROPHY ROOM',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonPurple),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: CyberpunkTheme.neonCyan,
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: SafeArea(
          bottom: false,
          child: trophyRoomAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonPurple),
              ),
            ),
            error: (error, stack) => Center(
              child: GlassPanel(
                borderColor: CyberpunkTheme.neonPink,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: CyberpunkTheme.neonPink, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'ERROR LOADING TROPHY ROOM',
                        style: TextStyle(
                          color: CyberpunkTheme.neonPink,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            data: (trophyRoomData) => userStatsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => const SizedBox.shrink(),
              data: (stats) => _buildTrophyRoom(context, trophyRoomData, stats),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrophyRoom(BuildContext context, TrophyRoomData data, UserStats stats) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - Identity Strip
            _buildIdentityStrip(stats),
            
            const SizedBox(height: 36),
            
            // Crown Wall - Featured Flex Cards
            _buildCrownWall(data),
            
            const SizedBox(height: 36),
            
            // Platinum Gallery - Carousel
            _buildPlatinumGallery(context, data),
            
            const SizedBox(height: 36),
            
            // Ultra Rare Flexes
            _buildUltraRareFlexes(data),
            
            const SizedBox(height: 24),
            
            // Recent Trophies
            _buildRecentTrophies(data),
            
            const SizedBox(height: 36),
            
            // Flex Poster Entry Point
            _buildFlexPosterButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityStrip(UserStats stats) {
    return Row(
      children: [
        PsnAvatar(
          avatarUrl: stats.avatarUrl,
          isPsPlus: stats.isPsPlus,
          size: 56,
          borderColor: CyberpunkTheme.neonPurple,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stats.username.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  fontSize: 22,
                  height: 1.1,
                  shadows: [
                    ...CyberpunkTheme.neonGlow(
                      color: CyberpunkTheme.neonPurple,
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Container(
                width: 60,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CyberpunkTheme.neonPurple,
                      CyberpunkTheme.neonPurple.withOpacity(0),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CyberpunkTheme.neonPurple.withOpacity(0.7),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrownWall(TrophyRoomData data) {
    final rarestPlat = data.rarestPlatinum;
    final newestPlat = data.newestPlatinum;
    final hardestPlat = data.hardestPlatinum;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CROWN WALL',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 2.5,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        
        // Use 2x2 grid on small screens, row on larger screens
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildCrownCard('RAREST\nPLATINUM', rarestPlat, CyberpunkTheme.neonOrange)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildCrownCard('NEWEST\nPLATINUM', newestPlat, CyberpunkTheme.neonCyan)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildCrownCard('HARDEST\nPLATINUM', hardestPlat, CyberpunkTheme.neonPink)),
                      const SizedBox(width: 12),
                      Expanded(child: Container()), // Placeholder for symmetry
                    ],
                  ),
                ],
              );
            } else {
              return Row(
                children: [
                  Expanded(child: _buildCrownCard('RAREST\nPLATINUM', rarestPlat, CyberpunkTheme.neonOrange)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCrownCard('NEWEST\nPLATINUM', newestPlat, CyberpunkTheme.neonCyan)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildCrownCard('HARDEST\nPLATINUM', hardestPlat, CyberpunkTheme.neonPink)),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildCrownCard(String label, PlatinumTrophy? platinum, Color accentColor) {
    if (platinum == null) {
      return GlassPanel(
        borderColor: accentColor.withOpacity(0.3),
        child: Container(
          height: 180,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                color: accentColor.withOpacity(0.4),
                size: 40,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'NO DATA YET',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.2),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        // TODO: Navigate to game detail
      },
      child: GlassPanel(
        borderColor: accentColor,
        showGlow: true,
        child: Container(
          height: 180,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              
              // Game name
              Text(
                platinum.gameName.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  shadows: CyberpunkTheme.neonGlow(color: accentColor, blurRadius: 4),
                ),
              ),
              
              // Rarity or Date
              if (label.contains('RAREST') || label.contains('HARDEST')) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: accentColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.4),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Text(
                    '${platinum.rarity.toStringAsFixed(2)}%',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  DateFormat('MMM d, y').format(platinum.earnedAt),
                  style: TextStyle(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatinumGallery(BuildContext context, TrophyRoomData data) {
    if (data.platinums.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PLATINUM GALLERY',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 2.5,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 18),
        
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: data.platinums.length + 1, // +1 for "See All" chip
            itemBuilder: (context, index) {
              if (index == data.platinums.length) {
                // "See All" chip
                return _buildSeeAllPlatinumsChip(context);
              }
              
              final platinum = data.platinums[index];
              return _buildPlatinumChip(context, platinum);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlatinumChip(BuildContext context, PlatinumTrophy platinum) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        // TODO: Navigate to game detail
      },
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        child: GlassPanel(
          borderColor: CyberpunkTheme.platinumNeon,
          borderRadius: 12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Platinum icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: CyberpunkTheme.platinumNeon.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: CyberpunkTheme.platinumNeon, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: CyberpunkTheme.platinumNeon.withOpacity(0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events,
                  color: CyberpunkTheme.platinumNeon,
                  size: 28,
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Game name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  platinum.gameName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              
              const SizedBox(height: 4),
              
              // "PLATINUM" label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: CyberpunkTheme.platinumNeon.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'PLATINUM',
                  style: TextStyle(
                    color: CyberpunkTheme.platinumNeon,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeeAllPlatinumsChip(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        // Navigate to games screen filtered to platinums
        context.push('/games');
      },
      child: const SizedBox(
        width: 120,
        child: GlassPanel(
          borderColor: CyberpunkTheme.neonCyan,
          borderRadius: 12,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.grid_view,
                color: CyberpunkTheme.neonCyan,
                size: 36,
              ),
              SizedBox(height: 12),
              Text(
                'SEE ALL\nPLATINUMS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: CyberpunkTheme.neonCyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUltraRareFlexes(TrophyRoomData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ULTRA RARE FLEXES',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 2.5,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Trophies you\'ve earned with rarity under 2%',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        
        if (data.ultraRareTrophies.isEmpty)
          GlassPanel(
            borderColor: CyberpunkTheme.neonPink.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.stars,
                      color: Colors.white.withOpacity(0.3),
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'NO ULTRA-RARE TROPHIES YET',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Earn trophies with < 2% rarity to unlock this section',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          GlassPanel(
            child: Column(
              children: [
                ...data.ultraRareTrophies.asMap().entries.map((entry) {
                  final index = entry.key;
                  final trophy = entry.value;
                  return Column(
                    children: [
                      if (index > 0) const Divider(color: Colors.white12, height: 1),
                      _buildUltraRareTrophyItem(trophy),
                    ],
                  );
                }),
                
                // TODO: View All button (stub)
                if (data.ultraRareTrophies.length >= 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        // TODO: Navigate to full ultra-rare trophy list
                      },
                      child: const Text(
                        'VIEW ALL',
                        style: TextStyle(
                          color: CyberpunkTheme.neonPink,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildUltraRareTrophyItem(UltraRareTrophy trophy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          // Trophy tier icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTierColor(trophy.tier).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getTierColor(trophy.tier), width: 1.5),
            ),
            child: Icon(
              _getTierIcon(trophy.tier),
              color: _getTierColor(trophy.tier),
              size: 24,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Trophy info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trophy.trophyName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trophy.gameName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Rarity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: CyberpunkTheme.neonPink.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CyberpunkTheme.neonPink, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: CyberpunkTheme.neonPink.withOpacity(0.3),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              '${trophy.rarity.toStringAsFixed(2)}%',
              style: const TextStyle(
                color: CyberpunkTheme.neonPink,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTrophies(TrophyRoomData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RECENT TROPHIES',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 2.5,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your latest achievements across all games',
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 18),
        
        if (data.recentTrophies.isEmpty)
          GlassPanel(
            borderColor: CyberpunkTheme.neonCyan.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: Colors.white.withOpacity(0.3),
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'NO RECENT TROPHIES',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          GlassPanel(
            child: Column(
              children: data.recentTrophies.asMap().entries.map((entry) {
                final index = entry.key;
                final trophy = entry.value;
                return Column(
                  children: [
                    if (index > 0) const Divider(color: Colors.white12, height: 1),
                    _buildRecentTrophyItem(trophy),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentTrophyItem(RecentTrophy trophy) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          // Trophy tier icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getTierColor(trophy.tier).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _getTierColor(trophy.tier), width: 1),
            ),
            child: Icon(
              _getTierIcon(trophy.tier),
              color: _getTierColor(trophy.tier),
              size: 20,
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Trophy info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trophy.trophyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trophy.gameName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Earned date
          Text(
            _getRelativeTime(trophy.earnedAt),
            style: TextStyle(
              color: CyberpunkTheme.neonCyan.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlexPosterButton(BuildContext context) {
    return Center(
      child: NeonActionChip(
        label: 'Generate Trophy Poster',
        icon: Icons.auto_awesome,
        isPrimary: true,
        accentColor: CyberpunkTheme.neonPurple,
        onTap: () {
          HapticFeedback.lightImpact();
          // TODO: Navigate to poster generator or show coming soon
          context.push('/poster');
        },
      ),
    );
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return CyberpunkTheme.platinumNeon;
      case 'gold':
        return CyberpunkTheme.goldNeon;
      case 'silver':
        return CyberpunkTheme.silverNeon;
      case 'bronze':
        return CyberpunkTheme.bronzeNeon;
      default:
        return Colors.white70;
    }
  }

  IconData _getTierIcon(String tier) {
    switch (tier.toLowerCase()) {
      case 'platinum':
        return Icons.emoji_events;
      case 'gold':
        return Icons.emoji_events;
      case 'silver':
        return Icons.emoji_events;
      case 'bronze':
        return Icons.emoji_events;
      default:
        return Icons.star;
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 30) {
      return DateFormat('MMM d').format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
