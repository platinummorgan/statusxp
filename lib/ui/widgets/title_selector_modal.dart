import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/meta_achievement.dart';
import 'package:statusxp/data/repositories/meta_achievement_repository.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class TitleSelectorModal extends ConsumerStatefulWidget {
  final String userId;
  final String? currentTitleId;

  const TitleSelectorModal({
    super.key,
    required this.userId,
    this.currentTitleId,
  });

  @override
  ConsumerState<TitleSelectorModal> createState() => _TitleSelectorModalState();
}

class _TitleSelectorModalState extends ConsumerState<TitleSelectorModal> {
  List<MetaAchievement> _achievements = [];
  bool _isLoading = true;
  bool _showLockedOnly = false;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    setState(() => _isLoading = true);
    
    final repository = ref.read(metaAchievementRepositoryProvider);
    final achievements = await repository.getAllAchievements(widget.userId);
    
    if (mounted) {
      setState(() {
        _achievements = achievements;
        _isLoading = false;
      });
    }
  }

  List<MetaAchievement> get _filteredAchievements {
    if (_showLockedOnly) {
      return _achievements.where((a) => !a.isUnlocked).toList();
    }
    return _achievements.where((a) => a.isUnlocked).toList();
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'rarity':
        return const Color(0xFFFF1744);
      case 'volume':
        return CyberpunkTheme.neonPurple;
      case 'streak':
        return CyberpunkTheme.neonCyan;
      case 'platform':
        return const Color(0xFF00E676);
      case 'completion':
        return CyberpunkTheme.neonOrange;
      case 'time':
        return const Color(0xFFFFD600);
      case 'variety':
        return const Color(0xFFE91E63);
      case 'meta':
        return const Color(0xFF7C4DFF);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF0A0E27),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: CyberpunkTheme.neonOrange.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Select Title',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      shadows: [
                        Shadow(
                          color: CyberpunkTheme.neonOrange.withOpacity(0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Filter toggle
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Unlocked'),
                        icon: Icon(Icons.lock_open, size: 16),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Locked'),
                        icon: Icon(Icons.lock_outline, size: 16),
                      ),
                    ],
                    selected: {_showLockedOnly},
                    onSelectionChanged: (Set<bool> newSelection) {
                      setState(() {
                        _showLockedOnly = newSelection.first;
                      });
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return CyberpunkTheme.neonOrange.withOpacity(0.3);
                        }
                        return const Color(0xFF1a1f3a).withOpacity(0.5);
                      }),
                      foregroundColor: WidgetStateProperty.resolveWith((states) {
                        if (states.contains(WidgetState.selected)) {
                          return CyberpunkTheme.neonOrange;
                        }
                        return Colors.white.withOpacity(0.6);
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Achievement list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonOrange),
                    ),
                  )
                : _filteredAchievements.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _showLockedOnly ? Icons.lock : Icons.emoji_events,
                              size: 64,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _showLockedOnly
                                  ? 'All achievements unlocked! 🎉'
                                  : 'No unlocked titles yet',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredAchievements.length,
                        itemBuilder: (context, index) {
                          final achievement = _filteredAchievements[index];
                          return _buildAchievementTile(achievement);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementTile(MetaAchievement achievement) {
    final categoryColor = _getCategoryColor(achievement.category);
    final isSelected = achievement.id == widget.currentTitleId;
    final isLocked = !achievement.isUnlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? CyberpunkTheme.neonOrange.withOpacity(0.2)
            : const Color(0xFF1a1f3a).withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? CyberpunkTheme.neonOrange
              : categoryColor.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLocked
              ? null
              : () async {
                  final repository = ref.read(metaAchievementRepositoryProvider);
                  final success = await repository.selectTitle(widget.userId, achievement.id);
                  
                  if (success && mounted) {
                    Navigator.pop(context, achievement.displayTitle);
                  }
                },
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: isLocked ? 0.5 : 1.0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: categoryColor.withOpacity(0.5),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        isLocked ? '🔒' : (achievement.iconEmoji ?? '🏆'),
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Title and description
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          achievement.displayTitle,
                          style: TextStyle(
                            color: isLocked
                                ? Colors.white.withOpacity(0.5)
                                : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          achievement.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                        if (!isLocked) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Unlocked ${_formatDate(achievement.unlockedAt ?? DateTime.now())}',
                            style: TextStyle(
                              color: categoryColor.withOpacity(0.6),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: CyberpunkTheme.neonOrange,
                      size: 24,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} weeks ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} months ago';
    return '${(diff.inDays / 365).floor()} years ago';
  }
}
