import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/meta_achievement.dart';
import 'package:statusxp/data/repositories/meta_achievement_repository.dart';
import 'package:statusxp/services/achievement_checker_service.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/providers/connected_platforms_provider.dart';
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
  // Get user's connected platforms for filtering
  final connectedPlatforms = await ref.watch(connectedPlatformsProvider.future);
  return repository.getAllAchievements(userId, connectedPlatforms: connectedPlatforms);
});

/// Achievements Screen - View all meta-achievements and track progress
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  String _selectedCategory = 'all';
  String _selectedPlatformFilter = 'all'; // all, psn, xbox, steam, cross

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
    final userId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final achievementsAsync = ref.watch(allAchievementsProvider(userId));

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text('Achievements', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0A0E27),
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: achievementsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading achievements: $error', style: const TextStyle(color: Colors.white)),
        ),
        data: (achievements) {
          // Apply category filter
          var filtered = _selectedCategory == 'all'
              ? achievements
              : achievements.where((a) => a.category == _selectedCategory).toList();

          // Apply platform filter
          if (_selectedPlatformFilter != 'all') {
            filtered = filtered.where((a) {
              final requiredPlatforms = a.requiredPlatforms ?? [];
              if (_selectedPlatformFilter == 'cross') {
                // Cross-platform: must have all 3 platforms
                return requiredPlatforms.length == 3 &&
                    requiredPlatforms.contains('psn') &&
                    requiredPlatforms.contains('xbox') &&
                    requiredPlatforms.contains('steam');
              } else {
                // Single platform: must have EXACTLY 1 platform and it must match
                return requiredPlatforms.length == 1 &&
                    requiredPlatforms.contains(_selectedPlatformFilter);
              }
            }).toList();
          }

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

              // Platform Filter
              _buildPlatformFilters(context, achievements),

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

  Widget _buildPlatformFilters(BuildContext context, List<MetaAchievement> achievements) {
    // Count achievements per platform
    int psCount = 0;
    int xboxCount = 0;
    int steamCount = 0;
    int crossCount = 0;

    for (final achievement in achievements) {
      final platforms = achievement.requiredPlatforms ?? [];
      if (platforms.isEmpty) continue;

      if (platforms.length == 3 &&
          platforms.contains('psn') &&
          platforms.contains('xbox') &&
          platforms.contains('steam')) {
        crossCount++;
      } else if (platforms.contains('psn')) {
        psCount++;
      } else if (platforms.contains('xbox')) {
        xboxCount++;
      } else if (platforms.contains('steam')) {
        steamCount++;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildPlatformChip('PS', psCount, const Color(0xFF0070CC), Icons.videogame_asset, 'psn'),
              _buildPlatformChip('XBOX', xboxCount, const Color(0xFF107C10), Icons.sports_esports, 'xbox'),
              _buildPlatformChip('STEAM', steamCount, const Color(0xFF66C0F4), Icons.store, 'steam'),
              _buildPlatformChip('CROSS', crossCount, CyberpunkTheme.neonPurple, Icons.sync_alt, 'cross'),
            ],
          ),
          if (_selectedPlatformFilter != 'all') ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedPlatformFilter = 'all';
                });
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear Filter'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlatformChip(String label, int count, Color color, IconData icon, String filterValue) {
    final isSelected = _selectedPlatformFilter == filterValue;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedPlatformFilter = filterValue;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(isSelected ? 0.15 : 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(isSelected ? 0.5 : 0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                count.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
