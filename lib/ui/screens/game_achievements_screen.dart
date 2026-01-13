import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/services/achievement_guide_service.dart';
import 'package:statusxp/services/youtube_search_service.dart';
import 'package:statusxp/services/ai_credit_service.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/ui/screens/premium_subscription_screen.dart';
import 'package:statusxp/ui/widgets/create_trophy_request_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Game Achievements Screen - Shows achievements/trophies for a specific game on a platform
class GameAchievementsScreen extends ConsumerStatefulWidget {
  final String gameId;
  final String gameName;
  final String platform;
  final String? coverUrl;

  const GameAchievementsScreen({
    super.key,
    required this.gameId,
    required this.gameName,
    required this.platform,
    this.coverUrl,
  });

  @override
  ConsumerState<GameAchievementsScreen> createState() => _GameAchievementsScreenState();
}

class _GameAchievementsScreenState extends ConsumerState<GameAchievementsScreen> {
  List<Map<String, dynamic>> _achievements = [];
  bool _isLoading = true;
  String? _error;
  bool _showHiddenAchievements = false;
  final Map<String, bool> _expandedGroups = {'Base Game': true}; // Base Game expanded by default
  int _refreshKey = 0; // Key to force FutureBuilder refresh

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  void _refreshAICreditBadge() {
    // Force all FutureBuilders to rebuild with fresh credit data
    setState(() {
      _refreshKey++;
    });
  }

  Future<void> _loadAchievements() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      // Map specific platform codes to generic achievement platform identifiers
      String achievementPlatform;
      if (widget.platform.toUpperCase().startsWith('PS')) {
        achievementPlatform = 'psn';
      } else if (widget.platform.toUpperCase().startsWith('XBOX')) {
        achievementPlatform = 'xbox';
      } else if (widget.platform.toUpperCase().startsWith('STEAM')) {
        achievementPlatform = 'steam';
      } else {
        achievementPlatform = widget.platform.toLowerCase();
      }
      // Get achievements for this game - check both tables
      PostgrestList achievementsResponse;
      try {
        // Try achievements table first (Xbox/Steam/new PSN format)
        achievementsResponse = await supabase
            .from('achievements')
            .select('''
              id,
              name,
              description,
              icon_url,
              proxied_icon_url,
              rarity_global,
              rarity_band,
              base_status_xp,
              psn_trophy_type,
              xbox_gamerscore,
              xbox_is_secret,
              steam_hidden,
              is_platinum,
              is_dlc,
              dlc_name
            ''')
            .eq('game_title_id', widget.gameId)
            .eq('platform', achievementPlatform)
            .order('is_platinum', ascending: false)
            .order('psn_trophy_type', ascending: true, nullsFirst: false)
            .order('id', ascending: true);
        
        print('[GameAchievements] Found ${(achievementsResponse as List).length} achievements');
      } catch (e) {
        // If achievements table fails, try trophies table (old PSN format)
        try {
          achievementsResponse = await supabase
              .from('trophies')
              .select('''
                id,
                name,
                description,
                icon_url,
                proxied_icon_url,
                rarity_global,
                tier,
                hidden
              ''')
              .eq('game_title_id', widget.gameId);
          
          print('[GameAchievements] Found ${(achievementsResponse as List).length} trophies');
        } catch (e2) {
          throw Exception('Could not load achievements from either table');
        }
      }

      // Get user's earned achievements/trophies separately
      // We need to filter by game to avoid getting all 1000+ user achievements
      List userEarnedResponse;
      try {
        // Get earned achievements for THIS specific game using a join
        userEarnedResponse = await supabase
            .from('user_achievements')
            .select('''
              achievement_id,
              earned_at,
              achievements!inner(game_title_id, platform)
            ''')
            .eq('user_id', userId)
            .eq('achievements.game_title_id', widget.gameId)
            .eq('achievements.platform', achievementPlatform);
      } catch (e) {
        // Try user_trophies for PSN
        try {
          userEarnedResponse = await supabase
              .from('user_trophies')
              .select('''
                trophy_id,
                unlocked_at,
                trophies!inner(game_title_id)
              ''')
              .eq('user_id', userId)
              .eq('trophies.game_title_id', widget.gameId);
        } catch (e2) {
          userEarnedResponse = [];
        }
      }

      // Create a map of earned achievements
      final earnedMap = <String, String>{};
      for (final ua in userEarnedResponse) {
        final id = (ua['achievement_id'] ?? ua['trophy_id']).toString();
        final date = (ua['earned_at'] ?? ua['unlocked_at']) as String;
        earnedMap[id] = date;
      }
      print('[GameAchievements] First 5 earned IDs: ${earnedMap.keys.take(5).toList()}');

      // Merge the data
      final achievements = (achievementsResponse).map((ach) {
        final achievementId = ach['id'].toString();
        final earnedAt = earnedMap[achievementId];
        
        if (earnedAt != null) {
          print('[GameAchievements] Achievement ${ach['name']} (ID: $achievementId) is earned at $earnedAt');
        }
        
        // Normalize field names
        return {
          'id': ach['id'],
          'name': ach['name'],
          'description': ach['description'],
          'icon_url': ach['icon_url'],
          'rarity_global': ach['rarity_global'],
          'rarity_band': ach['rarity_band'],
          'base_status_xp': ach['base_status_xp'],
          'trophy_tier': ach['psn_trophy_type'] ?? ach['tier'], // psn_trophy_type from achievements, tier from trophies
          'xbox_gamerscore': ach['xbox_gamerscore'],
          'xbox_is_secret': ach['xbox_is_secret'],
          'steam_hidden': ach['steam_hidden'] ?? ach['hidden'],
          'is_platinum': ach['is_platinum'],
          'is_dlc': ach['is_dlc'] ?? false,
          'dlc_name': ach['dlc_name'],
          'earned_at': earnedAt,
          'is_earned': earnedAt != null,
        };
      }).toList();
      setState(() {
        _achievements = achievements;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getPlatformColor() {
    final platformLower = widget.platform.toLowerCase();
    if (platformLower.contains('ps') || platformLower == 'playstation') {
      return const Color(0xFF0070CC);
    } else if (platformLower.contains('xbox')) {
      return const Color(0xFF107C10);
    } else if (platformLower.contains('steam')) {
      return const Color(0xFF1B2838);
    }
    return CyberpunkTheme.neonCyan;
  }

  Color _getTrophyColor(String? trophyType) {
    if (trophyType == null) return Colors.white70;
    
    switch (trophyType.toLowerCase()) {
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'platinum':
        return CyberpunkTheme.neonPurple;
      default:
        return Colors.white70;
    }
  }

  IconData _getTrophyIcon(String? trophyType) {
    if (trophyType == null) return Icons.emoji_events_outlined;
    
    switch (trophyType.toLowerCase()) {
      case 'platinum':
        return Icons.emoji_events;
      case 'gold':
        return Icons.workspace_premium;
      case 'silver':
        return Icons.military_tech;
      case 'bronze':
        return Icons.stars;
      default:
        return Icons.emoji_events_outlined;
    }
  }

  String _getRarityLabel(String? rarityBand) {
    if (rarityBand == null) return 'Common';
    return rarityBand.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final platformColor = _getPlatformColor();

    // Filter achievements based on hidden toggle
    final displayedAchievements = _achievements.where((achievement) {
      final isSecret = achievement['xbox_is_secret'] as bool? ?? false;
      final isHidden = achievement['steam_hidden'] as bool? ?? false;
      final isEarned = achievement['is_earned'] as bool? ?? false;
      
      // Always show earned achievements
      if (isEarned) return true;
      
      // Show hidden/secret only if toggle is on
      if ((isSecret || isHidden) && !_showHiddenAchievements) return false;
      
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.gameName,
              style: const TextStyle(fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              widget.platform.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: platformColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Icon(
              _showHiddenAchievements ? Icons.visibility : Icons.visibility_off,
              color: _showHiddenAchievements ? platformColor : Colors.white54,
            ),
            tooltip: _showHiddenAchievements ? 'Hide secret achievements' : 'Show secret achievements',
            onPressed: () {
              setState(() {
                _showHiddenAchievements = !_showHiddenAchievements;
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error: $_error', style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  )
                : displayedAchievements.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _achievements.isEmpty
                                  ? 'No achievements found'
                                  : 'All achievements are hidden',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            if (_achievements.isNotEmpty && !_showHiddenAchievements)
                              TextButton.icon(
                                icon: const Icon(Icons.visibility),
                                label: const Text('Show Hidden Achievements'),
                                onPressed: () {
                                  setState(() {
                                    _showHiddenAchievements = true;
                                  });
                                },
                              ),
                          ],
                        ),
                      )
                    : _buildGroupedAchievements(displayedAchievements, platformColor),
      ),
    );
  }

  Widget _buildGroupedAchievements(List<Map<String, dynamic>> achievements, Color platformColor) {
    // Group achievements by DLC
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (final ach in achievements) {
      final isDlc = ach['is_dlc'] as bool? ?? false;
      final dlcName = ach['dlc_name'] as String?;
      final groupKey = isDlc && dlcName != null ? dlcName : 'Base Game';
      
      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(ach);
    }

    // Sort groups: Base Game first, then DLC groups by name
    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      if (a == 'Base Game') return -1;
      if (b == 'Base Game') return 1;
      return a.compareTo(b);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedKeys.length,
      itemBuilder: (context, groupIndex) {
        final groupName = sortedKeys[groupIndex];
        final groupAchievements = grouped[groupName]!;
        final earnedCount = groupAchievements.where((a) => a['is_earned'] == true).length;
        final totalCount = groupAchievements.length;

        final isExpanded = _expandedGroups[groupName] ?? false;

        return Padding(
          padding: EdgeInsets.only(top: groupIndex > 0 ? 8 : 0),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: const Color(0xFF0A0E27).withOpacity(0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: platformColor.withOpacity(0.3), width: 1),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _expandedGroups[groupName] = expanded;
                  });
                },
                tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                leading: Icon(
                  groupName == 'Base Game' ? Icons.stars : Icons.extension,
                  color: platformColor,
                  size: 24,
                ),
                title: Text(
                  groupName,
                  style: TextStyle(
                    color: platformColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$earnedCount / $totalCount',
                      style: TextStyle(
                        color: platformColor.withOpacity(0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: platformColor,
                    ),
                  ],
                ),
                children: groupAchievements.map((achievement) {
                  final isEarned = achievement['is_earned'] as bool? ?? false;
                  final earnedAt = achievement['earned_at'] as String?;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _buildAchievementCard(achievement, isEarned, earnedAt, platformColor),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAchievementCard(
    Map<String, dynamic> achievement,
    bool isEarned,
    String? earnedAt,
    Color platformColor,
  ) {
    final trophyType = achievement['trophy_tier'] as String?;
    final trophyColor = _getTrophyColor(trophyType);
    final rarityGlobal = achievement['rarity_global'] as num?;
    final rarityBand = achievement['rarity_band'] as String?;
    final statusXP = achievement['base_status_xp'] as num?;
    final gamerscore = achievement['xbox_gamerscore'] as int?;
    final isSecret = achievement['xbox_is_secret'] as bool? ?? false;
    final isHidden = achievement['steam_hidden'] as bool? ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF0A0E27).withOpacity(isEarned ? 0.9 : 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isEarned ? platformColor : Colors.white24,
          width: isEarned ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Icon, Title, Date
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: achievement['proxied_icon_url'] != null || achievement['icon_url'] != null
                      ? Image.network(
                          achievement['proxied_icon_url'] ?? achievement['icon_url'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          color: isEarned ? null : Colors.black54,
                          colorBlendMode: isEarned ? null : BlendMode.darken,
                          errorBuilder: (_, __, ___) => _buildPlaceholderIcon(trophyType, trophyColor),
                        )
                      : _buildPlaceholderIcon(trophyType, trophyColor),
                ),
                const SizedBox(width: 12),
                // Title and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and earned date row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              (isSecret || isHidden) && !isEarned
                                  ? 'Hidden Achievement'
                                  : achievement['name'] ?? 'Unknown',
                              style: TextStyle(
                                color: isEarned ? Colors.white : Colors.white54,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          // Earned date badge (top right)
                          if (isEarned && earnedAt != null) ...[
                            const SizedBox(width: 8),
                            _buildBadge(
                              _formatDate(earnedAt),
                              CyberpunkTheme.neonCyan,
                              Icons.check_circle,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Description
                      if ((!isSecret && !isHidden) || isEarned || _showHiddenAchievements)
                        Text(
                          achievement['description'] ?? '',
                          style: TextStyle(
                            color: isEarned ? Colors.white70 : Colors.white38,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            // Badges row below icon
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Trophy type (PSN)
                if (trophyType != null) ...[
                  _buildBadge(
                    trophyType.toUpperCase(),
                    trophyColor,
                    _getTrophyIcon(trophyType),
                  ),
                  const SizedBox(width: 6),
                ],
                // Gamerscore (Xbox)
                if (gamerscore != null && gamerscore > 0) ...[
                  _buildBadge(
                    '${gamerscore}G',
                    const Color(0xFF107C10),
                    Icons.stars,
                  ),
                  const SizedBox(width: 6),
                ],
                // Rarity
                if (rarityGlobal != null) ...[
                  _buildBadge(
                    '${rarityGlobal.toStringAsFixed(1)}% • ${_getRarityLabel(rarityBand)}',
                    _getRarityColor(rarityBand),
                    Icons.diamond_outlined,
                  ),
                  const SizedBox(width: 6),
                ],
                // StatusXP
                if (statusXP != null)
                  _buildBadge(
                    '${statusXP.toStringAsFixed(1)} XP',
                    CyberpunkTheme.neonPurple,
                    Icons.bolt,
                  ),
              ],
            ),
            // Action buttons row
            if ((!isSecret && !isHidden) || isEarned || _showHiddenAchievements) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () {
                        context.push(
                          '/achievement-comments/${achievement['id']}'
                          '?name=${Uri.encodeComponent(achievement['name'])}'
                          '&icon=${Uri.encodeComponent(achievement['icon_url'] ?? achievement['proxied_icon_url'] ?? '')}',
                        );
                      },
                      icon: const Icon(Icons.chat_bubble_outline, size: 14),
                      label: const Text('Tips/Comments', style: TextStyle(fontSize: 10)),
                      style: TextButton.styleFrom(
                        foregroundColor: CyberpunkTheme.neonCyan,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    flex: 2,
                    child: FutureBuilder<AICreditStatus>(
                      key: ValueKey('credit_badge_${achievement['id']}_$_refreshKey'),
                      future: AICreditService().checkCredits(),
                      builder: (context, snapshot) {
                        final creditBadge = snapshot.hasData ? snapshot.data!.badgeText : '...';
                        
                        return TextButton.icon(
                          onPressed: () => _showAIGuideDialog(context, achievement),
                          icon: const Icon(Icons.lightbulb_outline, size: 14),
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('AI Help', style: TextStyle(fontSize: 10)),
                              const SizedBox(width: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: CyberpunkTheme.neonPurple.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: CyberpunkTheme.neonPurple,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  creditBadge,
                                  style: const TextStyle(
                                    color: CyberpunkTheme.neonPurple,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: CyberpunkTheme.neonPurple,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (!isEarned) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => CreateTrophyRequestDialog(
                          gameId: widget.gameId,
                          gameTitle: widget.gameName,
                          achievementId: achievement['id'].toString(),
                          achievementName: achievement['name'],
                          platform: widget.platform.toLowerCase().startsWith('ps')
                              ? 'psn'
                              : widget.platform.toLowerCase().startsWith('xbox')
                                  ? 'xbox'
                                  : 'steam',
                        ),
                      );
                      
                      if (result == true && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('View your request in Co-op Partners'),
                            action: SnackBarAction(
                              label: 'View',
                              onPressed: () {
                                context.push('/coop-partners');
                              },
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.handshake, size: 16),
                    label: const Text('Find Partner', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: CyberpunkTheme.neonCyan,
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(String? trophyType, Color color) {
    return Container(
      width: 60,
      height: 60,
      color: Colors.black38,
      child: Icon(_getTrophyIcon(trophyType), color: color, size: 30),
    );
  }

  Widget _buildBadge(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRarityColor(String? rarityBand) {
    if (rarityBand == null) return Colors.grey;
    
    switch (rarityBand.toLowerCase()) {
      case 'ultra_rare':
        return CyberpunkTheme.neonPurple;
      case 'very_rare':
        return CyberpunkTheme.neonPink;
      case 'rare':
        return CyberpunkTheme.neonCyan;
      case 'uncommon':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
      if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
      return '${(diff.inDays / 365).floor()}y ago';
    } catch (e) {
      return isoDate;
    }
  }

  Future<void> _showAIGuideDialog(BuildContext context, Map<String, dynamic> achievement) async {
    final achievementName = achievement['name'] as String? ?? 'Unknown Achievement';
    final achievementDescription = achievement['description'] as String? ?? '';
    
    // Check AI credits first
    final creditService = AICreditService();
    final creditStatus = await creditService.checkCredits();
    
    if (!creditStatus.canUse) {
      // Show purchase dialog
      _showAIPurchaseDialog(context, creditStatus);
      return;
    }
    
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(20),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.lightbulb,
                    color: CyberpunkTheme.neonPurple,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'ACHIEVEMENT GUIDE',
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
              
              // Achievement name
              Text(
                achievementName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (achievementDescription.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  achievementDescription,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              
              // AI Guide content
              Expanded(
                child: _AIGuideContent(
                  gameTitle: widget.gameName,
                  achievementName: achievementName,
                  achievementDescription: achievementDescription,
                  platform: widget.platform,
                  achievementId: achievement['id']?.toString(),
                  onCreditConsumed: _refreshAICreditBadge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    // Refresh AI credit badge after dialog closes
    _refreshAICreditBadge();
  }

  void _showAIPurchaseDialog(BuildContext context, AICreditStatus status) {
    final creditService = AICreditService();
    final packs = creditService.getAvailablePacks();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450, maxHeight: 700),
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
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.lightbulb,
                    color: CyberpunkTheme.neonPurple,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'OUT OF AI CREDITS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'Free AI used up for today',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.white70,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 32),
              
              // Free option
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.schedule, color: CyberpunkTheme.neonCyan, size: 32),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wait until tomorrow',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Get 3 more free AI uses tomorrow',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              const Text(
                'OR BUY AI PACK',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              
              // Pack options
              ...packs.map((pack) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    _purchaseAIPack(context, pack);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: pack.badge != null 
                            ? CyberpunkTheme.neonPurple 
                            : Colors.white24,
                        width: pack.badge != null ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_bag,
                          color: pack.badge != null 
                              ? CyberpunkTheme.neonPurple 
                              : CyberpunkTheme.neonCyan,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    pack.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (pack.badge != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: CyberpunkTheme.neonPurple,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        pack.badge!,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              Text(
                                '${pack.credits} AI uses · ${pack.perUsePrice}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          pack.displayPrice,
                          style: const TextStyle(
                            color: CyberpunkTheme.neonCyan,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
              
              const SizedBox(height: 16),
              
              // Premium option teaser
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CyberpunkTheme.neonPurple.withOpacity(0.2),
                      CyberpunkTheme.neonCyan.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CyberpunkTheme.neonPurple.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: CyberpunkTheme.neonPurple, size: 32),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Premium',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Unlimited syncs, AI guides & ad-free · \$4.99/mo',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PremiumSubscriptionScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'LEARN MORE',
                        style: TextStyle(
                          color: CyberpunkTheme.neonPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
    );
  }

  void _purchaseAIPack(BuildContext context, AIPack pack) async {
    final subscriptionService = SubscriptionService();
    
    // Check if user is premium (shouldn't see this, but double-check)
    final isPremium = await subscriptionService.isPremiumActive();
    if (isPremium) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Already Premium'),
            content: const Text(
              'You already have unlimited AI guides with your Premium subscription!\n\n'
              'No need to purchase AI packs. Enjoy unlimited access! 🎉'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }
    
    // Handle web purchases with Stripe
    if (kIsWeb) {
      await _purchaseAIPackWeb(context, pack);
      return;
    }
    
    // Handle mobile IAP purchases
    final productId = _getProductIdForPack(pack.type);
    final product = subscriptionService.aiPackProducts.firstWhere(
      (p) => p.id == productId,
      orElse: () => throw Exception('Product not found'),
    );
    
    if (!context.mounted) return;
    
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Purchase ${pack.title}?'),
        content: Text(
          'Get ${pack.credits} AI achievement guides for ${pack.displayPrice}.\n\n'
          'This is a one-time purchase. Credits never expire!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('PURCHASE'),
          ),
        ],
      ),
    );
    
    if (confirmed != true || !context.mounted) return;
    
    // Attempt purchase
    try {
      final success = await subscriptionService.purchaseAIPack(product);
      
      if (!context.mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${pack.credits} AI credits added!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Purchase cancelled or failed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _purchaseAIPackWeb(BuildContext context, AIPack pack) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Refresh session
      final sessionResponse = await supabase.auth.refreshSession();
      if (sessionResponse.session == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in again'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      
      // Call Stripe checkout for AI pack
      final response = await supabase.functions.invoke(
        'stripe-ai-pack-checkout',
        body: {
          'packType': pack.type,
          'credits': pack.credits,
          'price': pack.price,
        },
        headers: {
          'Authorization': 'Bearer ${sessionResponse.session!.accessToken}',
        },
      );

      if (response.data != null && response.data['url'] != null) {
        final checkoutUrl = response.data['url'] as String;
        final uri = Uri.parse(checkoutUrl);
        
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open payment page'), backgroundColor: Colors.red),
            );
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create checkout session'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      print('AI pack checkout error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start checkout: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  
  String _getProductIdForPack(String packType) {
    switch (packType) {
      case 'small':
        return SubscriptionService.aiPackSmallId;
      case 'medium':
        return SubscriptionService.aiPackMediumId;
      case 'large':
        return SubscriptionService.aiPackLargeId;
      default:
        throw Exception('Unknown pack type: $packType');
    }
  }

  /// Detects if an achievement is likely multiplayer/co-op based on keywords
  bool _isMultiplayerAchievement(Map<String, dynamic> achievement) {
    final name = (achievement['name'] as String? ?? '').toLowerCase();
    final description = (achievement['description'] as String? ?? '').toLowerCase();
    final combined = '$name $description';

    // Always log in web builds
    print('[MULTIPLAYER CHECK] Name: $name');
    print('[MULTIPLAYER CHECK] Description: $description');

    // List of multiplayer/co-op keywords
    const multiplayerKeywords = [
      'multiplayer',
      'multi-player',
      'co-op',
      'coop',
      'cooperative',
      'online',
      'with a friend',
      'with friend',
      'with friends',
      'with other',
      '2 player',
      'two player',
      '3 player',
      'three player',
      '4 player',
      'four player',
      'squad',
      'team',
      'party',
      'raid',
      'pvp',
      'versus',
      'matchmaking',
      'lobby',
      'player',           // catch "a player", "another player"
      'players',          // catch "other players"
      'opponent',         // catch "opponent", "opponents"
      'adversary',
      'adversaries',
      'competitive',
      'deathmatch',
      'domination',       // game mode
      'capture',          // capture the flag, etc
      'ranked',
      'unranked',
      'leaderboard',
    ];

    final isMultiplayer = multiplayerKeywords.any((keyword) => combined.contains(keyword));
    
    // Always log
    print('[MULTIPLAYER CHECK] Is multiplayer: $isMultiplayer');
    
    return isMultiplayer;
  }
}

/// Widget that displays AI-generated achievement guide with streaming support
class _AIGuideContent extends StatefulWidget {
  final String gameTitle;
  final String achievementName;
  final String achievementDescription;
  final String platform;
  final String? achievementId;
  final VoidCallback? onCreditConsumed;

  const _AIGuideContent({
    required this.gameTitle,
    required this.achievementName,
    required this.achievementDescription,
    required this.platform,
    this.achievementId,
    this.onCreditConsumed,
  });

  @override
  State<_AIGuideContent> createState() => _AIGuideContentState();
}

class _AIGuideContentState extends State<_AIGuideContent> {
  final _guideService = AchievementGuideService();
  String _guideText = '';
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGuide();
  }

  Future<void> _loadGuide() async {
    // Always consume AI credit (even for cached guides)
    final creditService = AICreditService();
    try {
      await creditService.consumeCredit();
      // Immediately refresh the credit badge on the parent screen
      widget.onCreditConsumed?.call();
    } catch (e) {
      setState(() {
        _error = 'Failed to use AI credit: $e';
        _isLoading = false;
      });
      return;
    }

    // Check if we already have a cached guide in the database
    final cached = await _checkCachedGuide();
    if (cached != null) {
      print('✅ Loaded guide from cache (${cached.length} chars)');
      setState(() {
        _guideText = cached;
      });
      
      // Search for YouTube video even for cached guides (if not already included)
      if (!_guideText.contains('youtube.com')) {
        print('🎥 Cached guide has no YouTube link - searching...');
        await _appendYouTubeLink();
        // Update database with YouTube link if found
        if (_guideText.contains('youtube.com')) {
          await _saveGuideToDatabase(_guideText);
        }
      } else {
        print('✅ Cached guide already has YouTube link');
      }
      
      setState(() {
        _isLoading = false;
      });
      return;
    }

    print('🤖 No cached guide - generating new one with AI...');
    
    // No cached guide found - generate new one with ChatGPT
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stream = _guideService.generateGuide(
        gameTitle: widget.gameTitle,
        achievementName: widget.achievementName,
        achievementDescription: widget.achievementDescription,
        platform: widget.platform,
      );

      await for (final chunk in stream) {
        setState(() {
          _guideText += chunk;
        });
      }

      print('✅ AI guide generation complete - now searching for YouTube video...');
      
      // Search for YouTube video and append to guide
      await _appendYouTubeLink();
      
      print('✅ YouTube search complete - now saving to database...');

      // Save to database
      await _saveGuideToDatabase(_guideText);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Error in guide generation flow: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _appendYouTubeLink() async {
    try {
      print('🎥 Starting YouTube search for: "${widget.gameTitle}" - "${widget.achievementName}"');
      final youtubeService = YouTubeSearchService();
      final videoUrl = await youtubeService.searchAchievementGuide(
        gameTitle: widget.gameTitle,
        achievementName: widget.achievementName,
      );

      if (videoUrl != null) {
        print('✅ YouTube video found: $videoUrl');
        // Replace "No specific video guide found" with actual link
        setState(() {
          if (_guideText.contains('No specific video guide found')) {
            _guideText = _guideText.replaceAll(
              'No specific video guide found',
              videoUrl,
            );
          } else {
            // If AI didn't include YouTube section, append it
            _guideText += '\n\nYouTube reference:\n$videoUrl';
          }
        });
      } else {
        print('⚠️ No YouTube video found');
      }
    } catch (e) {
      print('❌ YouTube search error: $e');
      // Continue without YouTube link if it fails
    }
  }

  Future<String?> _checkCachedGuide() async {
    if (widget.achievementId == null) {
      print('❌ Achievement ID is null - cannot check cache');
      return null;
    }

    try {
      print('🔍 Checking cache for achievement ID: ${widget.achievementId}');
      final supabase = Supabase.instance.client;
      
      // Parse achievementId as int (database id column is integer)
      final achievementId = int.tryParse(widget.achievementId!);
      if (achievementId == null) {
        print('❌ Invalid achievement ID format: ${widget.achievementId}');
        return null;
      }
      
      print('🔎 Querying achievements table for ID: $achievementId');
      final response = await supabase
          .from('achievements')
          .select('ai_guide, ai_guide_generated_at')
          .eq('id', achievementId)
          .single();

      print('📊 Database response: $response');
      final cachedGuide = response['ai_guide'] as String?;
      final generatedAt = response['ai_guide_generated_at'] as String?;
      
      if (cachedGuide != null && cachedGuide.isNotEmpty) {
        print('✅ Found cached guide (${cachedGuide.length} chars) generated at: $generatedAt');
        return cachedGuide;
      } else {
        print('⚠️ No cached guide found - ai_guide: $cachedGuide, generated_at: $generatedAt');
        return null;
      }
    } catch (e) {
      print('❌ Error checking cached guide: $e');
      return null;
    }
  }

  Future<void> _saveGuideToDatabase(String guide) async {
    if (widget.achievementId == null) {
      print('❌ Cannot save guide - achievement ID is null');
      return;
    }

    try {
      print('💾 Saving guide to database for achievement ID: ${widget.achievementId}');
      final supabase = Supabase.instance.client;
      
      // Parse achievementId as int (database id column is integer)
      final achievementId = int.tryParse(widget.achievementId!);
      if (achievementId == null) {
        print('❌ Invalid achievement ID format: ${widget.achievementId}');
        return;
      }
      
      // First verify the record exists
      print('🔍 Verifying achievement exists in database...');
      final existsCheck = await supabase
          .from('achievements')
          .select('id, name')
          .eq('id', achievementId)
          .maybeSingle();
      
      if (existsCheck == null) {
        print('❌ Achievement ID $achievementId does not exist in database');
        return;
      }
      print('✅ Achievement exists: ${existsCheck['name']} (ID: ${existsCheck['id']})');
      
      print('💾 Attempting to update achievement ID: $achievementId with guide (${guide.length} chars)');
      
      // Try simple update first without select
      await supabase
          .from('achievements')
          .update({
            'ai_guide': guide,
            'ai_guide_generated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', achievementId);
      
      print('📝 Update query executed, verifying if it worked...');
      
      // Verify the update worked by querying the record again
      final verification = await supabase
          .from('achievements')
          .select('id, ai_guide, ai_guide_generated_at')
          .eq('id', achievementId)
          .single();
      
      final savedGuide = verification['ai_guide'] as String?;
      final savedAt = verification['ai_guide_generated_at'] as String?;
      
      if (savedGuide != null && savedGuide.isNotEmpty) {
        print('✅ Update successful! Guide saved (${savedGuide.length} chars) at $savedAt');
      } else {
        print('❌ Update failed - guide is still null/empty');
        print('🔍 Full verification result: $verification');
      }
    } catch (e) {
      print('❌ Error saving guide: $e');
      // Also print the stack trace to see more details
      print('Stack trace: ${StackTrace.current}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: CyberpunkTheme.neonPink, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Error generating guide',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _error = null;
                  _guideText = '';
                });
                _loadGuide();
              },
              child: const Text('RETRY'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading && _guideText.isEmpty)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonPurple),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Generating guide...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          else
            _buildGuideText(),
          if (_isLoading && _guideText.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonPurple),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Generating...',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGuideText() {
    final urlPattern = RegExp(r'https?://[^\s]+');
    final matches = urlPattern.allMatches(_guideText);
    
    if (matches.isEmpty) {
      // No URLs, just show plain text
      return Text(
        _guideText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.5,
        ),
      );
    }

    // Build text with clickable links
    final spans = <InlineSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      // Add text before the URL
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: _guideText.substring(lastIndex, match.start),
          style: const TextStyle(color: Colors.white),
        ));
      }

      // Add clickable URL
      final url = match.group(0)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => _launchURL(url),
          child: Text(
            url,
            style: const TextStyle(
              color: CyberpunkTheme.neonCyan,
              decoration: TextDecoration.underline,
              fontSize: 14,
            ),
          ),
        ),
      ));

      lastIndex = match.end;
    }

    // Add remaining text after last URL
    if (lastIndex < _guideText.length) {
      spans.add(TextSpan(
        text: _guideText.substring(lastIndex),
        style: const TextStyle(color: Colors.white),
      ));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          height: 1.5,
        ),
        children: spans,
      ),
    );
  }

  Future<void> _launchURL(String url) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A0E27),
        title: const Text(
          'Open External Link',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will open YouTube in your browser or YouTube app.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              url,
              style: const TextStyle(
                color: CyberpunkTheme.neonCyan,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: CyberpunkTheme.neonCyan,
            ),
            child: const Text('OPEN'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
      }
    }
  }
}
