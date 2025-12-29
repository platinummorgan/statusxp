import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/meta_achievement.dart';
import 'package:statusxp/data/repositories/meta_achievement_repository.dart';
import 'package:statusxp/services/achievement_checker_service.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final metaAchievementRepositoryProvider = Provider<MetaAchievementRepository>((ref) {
  return MetaAchievementRepository(Supabase.instance.client);
});

final achievementCheckerServiceProvider = Provider<AchievementCheckerService>((ref) {
  return AchievementCheckerService(Supabase.instance.client);
});

final allAchievementsProvider = FutureProvider.family<List<MetaAchievement>, String>((ref, userId) async {
  final repository = ref.read(metaAchievementRepositoryProvider);
  return repository.getAllAchievements(userId);
});

/// Achievements Screen - View all meta-achievements and track progress
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  String _selectedCategory = 'all';

  final Map<String, String> _categoryNames = {
    'all': 'All Achievements',
    'rarity': 'Rarity',
    'volume': 'Volume',
    'streak': 'Streaks',
    'platform': 'Platform',
    'completion': 'Completion',
    'time': 'Time',
    'variety': 'Variety',
    'meta': 'Meta',
  };

  @override
  void initState() {
    super.initState();
    // Check for new achievements when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAchievements();
    });
  }

  Future<void> _checkAchievements() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    
    final checker = ref.read(achievementCheckerServiceProvider);
    
    try {
      final newlyUnlocked = await checker.checkAndUnlockAchievements(userId);
      
      if (!mounted) return;
      
      if (newlyUnlocked.isNotEmpty) {
        // Refresh the achievements list
        ref.invalidate(allAchievementsProvider);
        
        // Get the full achievement objects to show names
        final allAchievements = ref.read(allAchievementsProvider(userId)).valueOrNull ?? [];
        final unlockedAchievements = allAchievements
            .where((a) => newlyUnlocked.contains(a.id))
            .toList();
        
        if (!mounted) return;
        
        // Show success dialog with details
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1A1E3C),
            title: const Text('🎉 Achievements Unlocked!', style: TextStyle(color: Colors.white)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You unlocked ${newlyUnlocked.length} achievement(s):',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ...unlockedAchievements.map((achievement) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• ${achievement.defaultTitle}', style: const TextStyle(color: CyberpunkTheme.neonPurple)),
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Awesome!'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Silently fail on auto-check - user can still manually refresh
      debugPrint('Achievement auto-check failed: $e');
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'rarity': return const Color(0xFFE91E63); // Pink/Red
      case 'volume': return const Color(0xFF9C27B0); // Purple
      case 'streak': return const Color(0xFF00BCD4); // Cyan
      case 'platform': return const Color(0xFF2196F3); // Blue
      case 'completion': return const Color(0xFF4CAF50); // Green
      case 'time': return const Color(0xFFFF9800); // Orange
      case 'variety': return const Color(0xFFFFEB3B); // Yellow
      case 'meta': return const Color(0xFF607D8B); // Blue Grey
      default: return CyberpunkTheme.neonPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    const userId = '84b60ad6-cb2c-484f-8953-bf814551fd7a'; // TODO: Get from auth
    final achievementsAsync = ref.watch(allAchievementsProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text('Achievements', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A0E27),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: achievementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading achievements: $error', style: const TextStyle(color: Colors.white)),
        ),
        data: (achievements) {
          final filtered = _selectedCategory == 'all'
              ? achievements
              : achievements.where((a) => a.category == _selectedCategory).toList();

          final unlockedCount = achievements.where((a) => a.isUnlocked).length;
          final totalCount = achievements.length;

          return Column(
            children: [
              // Progress Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CyberpunkTheme.neonPurple.withOpacity(0.2),
                      CyberpunkTheme.neonOrange.withOpacity(0.1),
                    ],
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      '$unlockedCount / $totalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Achievements Unlocked',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: unlockedCount / totalCount,
                        minHeight: 8,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonPurple),
                      ),
                    ),
                  ],
                ),
              ),

              // Category Filter
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _categoryNames.length,
                  itemBuilder: (context, index) {
                    final categoryKey = _categoryNames.keys.elementAt(index);
                    final categoryName = _categoryNames[categoryKey]!;
                    final isSelected = _selectedCategory == categoryKey;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(categoryName),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = categoryKey;
                          });
                        },
                        backgroundColor: const Color(0xFF1A1E3C),
                        selectedColor: categoryKey == 'all' 
                            ? CyberpunkTheme.neonPurple 
                            : _getCategoryColor(categoryKey),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Achievements List
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No achievements in this category',
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final achievement = filtered[index];
                          return _buildAchievementTile(achievement);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAchievementTile(MetaAchievement achievement) {
    final categoryColor = _getCategoryColor(achievement.category);
    final isUnlocked = achievement.isUnlocked;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked ? categoryColor.withOpacity(0.5) : Colors.white10,
          width: 2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: categoryColor.withOpacity(isUnlocked ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: categoryColor.withOpacity(isUnlocked ? 0.5 : 0.2),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              isUnlocked ? (achievement.iconEmoji ?? '🏆') : '🔒',
              style: TextStyle(
                fontSize: 28,
                color: isUnlocked ? Colors.white : Colors.white38,
              ),
            ),
          ),
        ),
        title: Text(
          achievement.displayTitle,
          style: TextStyle(
            color: isUnlocked ? Colors.white : Colors.white38,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              achievement.description,
              style: TextStyle(
                color: isUnlocked ? Colors.white70 : Colors.white24,
                fontSize: 13,
              ),
            ),
            if (isUnlocked && achievement.unlockedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: categoryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Unlocked ${_formatDate(achievement.unlockedAt!)}',
                    style: TextStyle(
                      color: categoryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        trailing: !isUnlocked
            ? null
            : Icon(
                Icons.star,
                color: categoryColor,
                size: 28,
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
