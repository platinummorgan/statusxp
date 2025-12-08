import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      print('[GameAchievements] Loading for gameId: ${widget.gameId}, platform: ${widget.platform}');

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

      print('[GameAchievements] Mapped to achievement platform: $achievementPlatform');

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
            .eq('platform', achievementPlatform);
        
        print('[GameAchievements] Found ${(achievementsResponse as List).length} achievements');
      } catch (e) {
        print('[GameAchievements] achievements table error: $e');
        // If achievements table fails, try trophies table (old PSN format)
        try {
          achievementsResponse = await supabase
              .from('trophies')
              .select('''
                id,
                name,
                description,
                icon_url,
                rarity_global,
                tier,
                hidden
              ''')
              .eq('game_title_id', widget.gameId);
          
          print('[GameAchievements] Found ${(achievementsResponse as List).length} trophies');
        } catch (e2) {
          print('[GameAchievements] trophies table error: $e2');
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
        print('[GameAchievements] user_achievements error: $e');
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
          print('[GameAchievements] user_trophies error: $e2');
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

      print('[GameAchievements] Earned map has ${earnedMap.length} entries');
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

      print('[GameAchievements] Merged ${achievements.length} achievements with user data');

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: achievement['icon_url'] != null
                  ? Image.network(
                      achievement['icon_url'],
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
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    (isSecret || isHidden) && !isEarned
                        ? 'Hidden Achievement'
                        : achievement['name'] ?? 'Unknown',
                    style: TextStyle(
                      color: isEarned ? Colors.white : Colors.white54,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
                  const SizedBox(height: 8),
                  // Badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      // Trophy type (PSN)
                      if (trophyType != null)
                        _buildBadge(
                          trophyType.toUpperCase(),
                          trophyColor,
                          _getTrophyIcon(trophyType),
                        ),
                      // Gamerscore (Xbox)
                      if (gamerscore != null && gamerscore > 0)
                        _buildBadge(
                          '${gamerscore}G',
                          const Color(0xFF107C10),
                          Icons.stars,
                        ),
                      // Rarity
                      if (rarityGlobal != null)
                        _buildBadge(
                          '${rarityGlobal.toStringAsFixed(1)}% • ${_getRarityLabel(rarityBand)}',
                          _getRarityColor(rarityBand),
                          Icons.diamond_outlined,
                        ),
                      // StatusXP
                      if (statusXP != null)
                        _buildBadge(
                          '${statusXP.toStringAsFixed(1)} XP',
                          CyberpunkTheme.neonOrange,
                          Icons.bolt,
                        ),
                      // Earned date
                      if (isEarned && earnedAt != null)
                        _buildBadge(
                          _formatDate(earnedAt),
                          CyberpunkTheme.neonCyan,
                          Icons.check_circle,
                        ),
                    ],
                  ),
                ],
              ),
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
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
}
