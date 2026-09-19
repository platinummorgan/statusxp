import 'package:statusxp/ui/widgets/game_achievement_card.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/ui/screens/ai_credit_shop_screen.dart';

import 'package:statusxp/utils/statusxp_logger.dart';

/// Game Achievements Screen - Shows achievements/trophies for a specific game on a platform
class GameAchievementsScreen extends ConsumerStatefulWidget {
  final int? platformId;
  final String? platformGameId;
  final String gameName;
  final String platform;
  final String? coverUrl;

  const GameAchievementsScreen({
    super.key,
    required this.platformId,
    required this.platformGameId,
    required this.gameName,
    required this.platform,
    this.coverUrl,
  });

  @override
  ConsumerState<GameAchievementsScreen> createState() =>
      _GameAchievementsScreenState();
}

class _GameAchievementsScreenState
    extends ConsumerState<GameAchievementsScreen> {
  List<Map<String, dynamic>> _achievements = [];
  bool _isLoading = true;
  String? _error;
  bool _showHiddenAchievements = false;
  bool _showRemainingOnly = false;
  final Map<String, bool> _expandedGroups = {
    'Base Game': true,
  }; // Base Game expanded by default

  bool _readBoolFlag(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'yes' ||
          normalized == 'hidden';
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  void _refreshAICreditBadge() {
    if (mounted) ref.invalidate(achievementCreditsProvider);
  }

  Future<void> _loadAchievements() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;

      // Validate V2 composite keys
      if (widget.platformId == null || widget.platformGameId == null) {
        throw Exception(
          'Missing platform_id or platform_game_id for V2 schema',
        );
      }

      // Loading achievements

      // Get achievements for this game (V2 schema - uses composite keys)
      final achievementsResponse = await supabase
          .from('achievements')
          .select('''
            platform_achievement_id,
            name,
            description,
            icon_url,
            proxied_icon_url,
            rarity_global,
            base_status_xp,
            rarity_multiplier,
            include_in_score,
            score_value,
            metadata
          ''')
          .eq('platform_id', widget.platformId!)
          .eq('platform_game_id', widget.platformGameId!);

      // Achievements loaded

      // Get user's earned achievements for this game using V2 schema
      final userEarnedResponse = await supabase
          .from('user_achievements')
          .select('platform_achievement_id, earned_at')
          .eq('user_id', userId)
          .eq('platform_id', widget.platformId!)
          .eq('platform_game_id', widget.platformGameId!);

      // Create a map of earned achievements (platform_achievement_id -> earned_at)
      final earnedMap = <String, String>{};
      for (final ua in userEarnedResponse) {
        final achId = ua['platform_achievement_id'] as String?;
        final date = ua['earned_at'] as String?;
        if (achId != null && date != null) {
          earnedMap[achId] = date;
        }
      }
      // User progress loaded

      // Merge the data
      final achievements = achievementsResponse.asMap().entries.map((entry) {
        final sourceIndex = entry.key;
        final ach = entry.value;
        final achievementId = ach['platform_achievement_id'] as String;
        final earnedAt = earnedMap[achievementId];
        final metadata = ach['metadata'] as Map<String, dynamic>? ?? {};

        // Debug: Log first achievement metadata
        if (kDebugMode && sourceIndex == 0) {
          statusxpLog('🔍 First achievement metadata structure:');
          statusxpLog('   Achievement: ${ach['name']}');
          statusxpLog('   metadata type: ${metadata.runtimeType}');
          statusxpLog('   metadata keys: ${metadata.keys.toList()}');
          statusxpLog(
            '   is_dlc value: ${metadata['is_dlc']} (type: ${metadata['is_dlc'].runtimeType})',
          );
          statusxpLog('   dlc_name value: ${metadata['dlc_name']}');
          statusxpLog('   Full metadata: $metadata');
        }

        // Extract platform-specific fields from metadata
        String? trophyType;
        int? gamerscore;
        bool isSecret = false;
        bool isHidden = false;
        bool isPlatinum = false;

        // PSN fields
        trophyType = metadata['psn_trophy_type'] as String?;
        isPlatinum = trophyType?.toLowerCase() == 'platinum';

        // Xbox fields
        gamerscore = metadata['xbox_gamerscore'] as int?;
        isSecret = metadata['xbox_is_secret'] as bool? ?? false;

        // Hidden fields (Steam + PSN)
        final steamHidden = _readBoolFlag(metadata['steam_hidden']);
        final psnHidden =
            _readBoolFlag(metadata['psn_hidden']) ||
            _readBoolFlag(metadata['hidden']);
        isHidden = steamHidden || psnHidden;

        // Calculate rarity band from rarity_global
        final rarityGlobal = (ach['rarity_global'] as num?)?.toDouble();
        String? rarityBand;
        if (rarityGlobal != null) {
          if (rarityGlobal < 1.0) {
            rarityBand = 'ULTRA_RARE';
          } else if (rarityGlobal < 5.0) {
            rarityBand = 'VERY_RARE';
          } else if (rarityGlobal < 15.0) {
            rarityBand = 'RARE';
          } else if (rarityGlobal < 50.0) {
            rarityBand = 'UNCOMMON';
          } else {
            rarityBand = 'COMMON';
          }
        }

        return {
          'id': ach['platform_achievement_id'],
          'platform_achievement_id':
              ach['platform_achievement_id'], // Keep for V2 composite keys
          'name': ach['name'],
          'description': ach['description'],
          'icon_url': kIsWeb && widget.platformId != 4
              ? (ach['proxied_icon_url'] ?? ach['icon_url'])
              : ach['icon_url'], // Xbox (4) has no CORS issues
          'proxied_icon_url': ach['proxied_icon_url'],
          'rarity_global': rarityGlobal,
          'rarity_band': rarityBand,
          'base_status_xp': ach['base_status_xp'],
          'psn_trophy_type': trophyType,
          'xbox_gamerscore': gamerscore,
          'xbox_is_secret': isSecret,
          'steam_hidden': _readBoolFlag(metadata['steam_hidden']),
          'psn_hidden':
              _readBoolFlag(metadata['psn_hidden']) ||
              _readBoolFlag(metadata['hidden']),
          'is_hidden': isHidden,
          'source_sort_order': metadata['sort_order'],
          'source_display_order': metadata['display_order'],
          'steam_display_order': metadata['steam_display_order'],
          '_original_index': sourceIndex,
          'is_platinum': isPlatinum,
          'include_in_score': ach['include_in_score'],
          'is_dlc': metadata['is_dlc'] as bool? ?? false,
          'dlc_name': metadata['dlc_name'],
          'trophy_group_id': metadata['trophy_group_id'],
          'earned_at': earnedAt,
          'is_earned': earnedAt != null,
        };
      }).toList();

      // Debug: Log DLC grouping info
      final dlcCount = achievements.where((a) => a['is_dlc'] == true).length;
      final withDlcName = achievements
          .where((a) => a['dlc_name'] != null)
          .length;
      final uniqueDlcNames = achievements
          .map((a) => a['dlc_name'])
          .where((name) => name != null)
          .toSet();
      final uniqueTrophyGroups = achievements
          .map((a) => a['trophy_group_id'])
          .where((id) => id != null && id != 'default')
          .toSet();

      if (kDebugMode) {
        statusxpLog('🎮 Achievements loaded for ${widget.gameName}:');
        statusxpLog('   Total: ${achievements.length}');
        statusxpLog('   Marked as DLC: $dlcCount');
        statusxpLog('   With DLC names: $withDlcName');
        statusxpLog('   Unique DLC groups: ${uniqueDlcNames.length}');
        statusxpLog(
          '   Unique trophy group IDs: ${uniqueTrophyGroups.length} - ${uniqueTrophyGroups.toList()}',
        );
        if (uniqueDlcNames.isNotEmpty) {
          statusxpLog('   DLC names: ${uniqueDlcNames.toList()}');
        }

        // Debug: Log first few achievements' DLC status
        statusxpLog('   First 5 achievements:');
        for (var i = 0; i < achievements.length && i < 5; i++) {
          final ach = achievements[i];
          statusxpLog(
            '     ${i + 1}. ${ach['name']}: trophy_group=${ach['trophy_group_id']}, dlc_name=${ach['dlc_name']}',
          );
        }
      }

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

  int? _parseOrderInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  int _resolvedNativeOrder(
    Map<String, dynamic> achievement, {
    required bool isPsn,
    required bool isXbox,
    required bool isSteam,
  }) {
    if (isPsn) {
      return _parseOrderInt(achievement['source_sort_order']) ??
          _parseOrderInt(achievement['platform_achievement_id']) ??
          2147483647;
    }

    if (isXbox) {
      return _parseOrderInt(achievement['source_display_order']) ??
          _parseOrderInt(achievement['platform_achievement_id']) ??
          2147483647;
    }

    if (isSteam) {
      return _parseOrderInt(achievement['steam_display_order']) ??
          _parseOrderInt(achievement['source_sort_order']) ??
          2147483647;
    }

    return _parseOrderInt(achievement['source_sort_order']) ?? 2147483647;
  }

  int _comparePlatformDefaultRows(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final platformLower = widget.platform.toLowerCase();
    final isPsn =
        platformLower == 'psn' ||
        platformLower.contains('playstation') ||
        platformLower.contains('ps');
    final isXbox = platformLower.contains('xbox');
    final isSteam = platformLower.contains('steam');

    final aOrder = _resolvedNativeOrder(
      a,
      isPsn: isPsn,
      isXbox: isXbox,
      isSteam: isSteam,
    );
    final bOrder = _resolvedNativeOrder(
      b,
      isPsn: isPsn,
      isXbox: isXbox,
      isSteam: isSteam,
    );
    final nativeCompare = aOrder.compareTo(bOrder);
    if (nativeCompare != 0) {
      return nativeCompare;
    }

    final aOriginal = _parseOrderInt(a['_original_index']) ?? 2147483647;
    final bOriginal = _parseOrderInt(b['_original_index']) ?? 2147483647;
    final originalCompare = aOriginal.compareTo(bOriginal);
    if (originalCompare != 0) {
      return originalCompare;
    }

    final aName = (a['name'] as String? ?? '').toLowerCase();
    final bName = (b['name'] as String? ?? '').toLowerCase();
    return aName.compareTo(bName);
  }

  @override
  Widget build(BuildContext context) {
    final platformColor = _getPlatformColor();

    // Filter achievements by progress status (All vs Remaining)
    final displayedAchievements = _achievements.where((achievement) {
      final isEarned = achievement['is_earned'] as bool? ?? false;
      if (_showRemainingOnly && isEarned) return false;
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
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Buy AI Credits',
            onPressed: () => _showAIPurchaseDialog(context),
          ),
          IconButton(
            icon: Icon(
              _showHiddenAchievements ? Icons.visibility : Icons.visibility_off,
              color: _showHiddenAchievements ? platformColor : Colors.white54,
            ),
            tooltip: _showHiddenAchievements
                ? 'Hide hidden trophy details'
                : 'Reveal hidden trophy details',
            onPressed: () {
              setState(() {
                _showHiddenAchievements = !_showHiddenAchievements;
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Container(
          decoration: CyberpunkTheme.gradientBackground(),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error: $_error',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    _buildAchievementFilterBar(platformColor),
                    Expanded(
                      child: displayedAchievements.isEmpty
                          ? Center(
                              child: Text(
                                _achievements.isEmpty
                                    ? 'No achievements found'
                                    : (_showRemainingOnly
                                          ? 'No remaining achievements'
                                          : 'No achievements found'),
                                style: const TextStyle(color: Colors.white70),
                              ),
                            )
                          : _buildGroupedAchievements(
                              displayedAchievements,
                              platformColor,
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildAchievementFilterBar(Color platformColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          ChoiceChip(
            label: const Text('All'),
            selected: !_showRemainingOnly,
            onSelected: (_) {
              setState(() {
                _showRemainingOnly = false;
              });
            },
            selectedColor: platformColor.withValues(alpha: 0.25),
            labelStyle: TextStyle(
              color: !_showRemainingOnly ? platformColor : Colors.white70,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: const Color(0xFF0A0E27).withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Remaining'),
            selected: _showRemainingOnly,
            onSelected: (_) {
              setState(() {
                _showRemainingOnly = true;
              });
            },
            selectedColor: platformColor.withValues(alpha: 0.25),
            labelStyle: TextStyle(
              color: _showRemainingOnly ? platformColor : Colors.white70,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: const Color(0xFF0A0E27).withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupedAchievements(
    List<Map<String, dynamic>> achievements,
    Color platformColor,
  ) {
    // Group achievements by DLC
    final Map<String, List<Map<String, dynamic>>> grouped = {};

    for (final ach in achievements) {
      final trophyGroupId = ach['trophy_group_id'] as String? ?? 'default';
      final dlcName = ach['dlc_name'] as String?;

      // Use trophy_group_id to determine grouping, fallback to "DLC X" if dlc_name is missing
      final groupKey = trophyGroupId != 'default'
          ? (dlcName ?? 'DLC $trophyGroupId')
          : 'Base Game';

      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(ach);
    }

    // Debug: Log grouping results
    if (kDebugMode) {
      statusxpLog('📦 Achievement grouping:');
      grouped.forEach((groupName, achs) {
        statusxpLog('   $groupName: ${achs.length} achievements');
      });
    }

    // Sort groups: Base Game first, then DLC groups by name
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
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
        final earnedCount = groupAchievements
            .where((a) => a['is_earned'] == true)
            .length;
        final totalCount = groupAchievements.length;

        final isExpanded = _expandedGroups[groupName] ?? false;

        return Padding(
          padding: EdgeInsets.only(top: groupIndex > 0 ? 8 : 0),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            color: const Color(0xFF0A0E27).withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: platformColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _expandedGroups[groupName] = expanded;
                  });
                },
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                childrenPadding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
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
                        color: platformColor.withValues(alpha: 0.8),
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
                children:
                    ([
                      ...groupAchievements,
                    ]..sort(_comparePlatformDefaultRows)).map((achievement) {
                      final isEarned =
                          achievement['is_earned'] as bool? ?? false;
                      final earnedAt = achievement['earned_at'] as String?;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildAchievementCard(
                          achievement,
                          isEarned,
                          earnedAt,
                          platformColor,
                        ),
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
  ) => GameAchievementCard(
    key: ValueKey(achievement['platform_achievement_id']),
    achievement: achievement,
    platformId: widget.platformId,
    platformGameId: widget.platformGameId,
    gameName: widget.gameName,
    platform: widget.platform,
    platformColor: platformColor,
    showHidden: _showHiddenAchievements,
  );

  Future<void> _showAIPurchaseDialog(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const AICreditShopScreen()));
    if (mounted) _refreshAICreditBadge();
  }
}
