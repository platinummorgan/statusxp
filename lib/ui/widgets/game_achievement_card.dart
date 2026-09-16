import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/services/achievement_guide_service.dart';
import 'package:statusxp/services/ai_credit_service.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/services/youtube_search_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/screens/ai_credit_shop_screen.dart';
import 'package:statusxp/ui/widgets/create_trophy_request_dialog.dart';
import 'package:statusxp/utils/statusxp_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Share one allowance read across all visible achievement cards.
final achievementCreditsProvider = FutureProvider.autoDispose<AICreditStatus>((
  ref,
) async {
  if (ref.watch(currentUserIdProvider) == null) {
    return AICreditStatus(
      canUse: false,
      source: 'none',
      remaining: 0,
      packCredits: 0,
      dailyFree: 0,
    );
  }
  return AICreditService().checkCredits();
});

final achievementGuideServiceProvider = Provider<AchievementGuideService>(
  (ref) => AchievementGuideService(),
);

/// Rich trophy presentation shared by the inline catalog and full trophy screen.
class GameAchievementCard extends ConsumerStatefulWidget {
  const GameAchievementCard({
    super.key,
    required this.achievement,
    required this.platformId,
    required this.platformGameId,
    required this.gameName,
    required this.platform,
    required this.platformColor,
    required this.showHidden,
  });
  final Map<String, dynamic> achievement;
  final int? platformId;
  final String? platformGameId;
  final String gameName;
  final String platform;
  final Color platformColor;
  final bool showHidden;

  @override
  ConsumerState<GameAchievementCard> createState() =>
      _GameAchievementCardState();
}

class _GameAchievementCardState extends ConsumerState<GameAchievementCard> {
  void _refreshAICreditBadge() {
    if (mounted) ref.invalidate(achievementCreditsProvider);
  }

  @override
  Widget build(BuildContext context) => _buildAchievementCard(
    widget.achievement,
    widget.achievement['is_earned'] == true,
    widget.achievement['earned_at'] as String?,
    widget.platformColor,
  );
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

  Widget _buildAchievementCard(
    Map<String, dynamic> achievement,
    bool isEarned,
    String? earnedAt,
    Color platformColor,
  ) {
    final trophyType = achievement['psn_trophy_type'] as String?;
    final trophyColor = _getTrophyColor(trophyType);
    final rarityGlobal = achievement['rarity_global'] as num?;
    final rarityBand = achievement['rarity_band'] as String?;
    final statusXP = achievement['base_status_xp'] as num?;
    final gamerscore = achievement['xbox_gamerscore'] as int?;
    final isSecret = achievement['xbox_is_secret'] as bool? ?? false;
    final isHidden = achievement['is_hidden'] as bool? ?? false;
    final shouldMaskDetails =
        (isSecret || isHidden) && !isEarned && !widget.showHidden;
    final safeAchievementName = shouldMaskDetails
        ? 'Hidden Achievement'
        : (achievement['name'] ?? 'Achievement');
    final safeAchievementDescription = shouldMaskDetails
        ? 'Description hidden. Use the eye icon to reveal.'
        : (achievement['description'] ?? '');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF0A0E27).withValues(alpha: isEarned ? 0.9 : 0.5),
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
                  child:
                      !shouldMaskDetails &&
                          (achievement['proxied_icon_url'] != null ||
                              achievement['icon_url'] != null)
                      ? Image.network(
                          kIsWeb
                              ? (achievement['proxied_icon_url'] ??
                                    achievement['icon_url'])
                              : (achievement['icon_url'] ??
                                    achievement['proxied_icon_url']),
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          color: isEarned ? null : Colors.black54,
                          colorBlendMode: isEarned ? null : BlendMode.darken,
                          errorBuilder: (_, __, ___) =>
                              _buildPlaceholderIcon(trophyType, trophyColor),
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
                            child: InkWell(
                              onTap:
                                  shouldMaskDetails ||
                                      widget.platformId == null ||
                                      widget.platformGameId == null
                                  ? null
                                  : () => context.push(
                                      AchievementRef(
                                        gameRef: GameRef(
                                          platformId: widget.platformId!,
                                          platformGameId:
                                              widget.platformGameId!,
                                        ),
                                        platformAchievementId:
                                            achievement['platform_achievement_id']
                                                .toString(),
                                      ).location,
                                    ),
                              child: Text(
                                safeAchievementName,
                                style: TextStyle(
                                  color: isEarned
                                      ? Colors.white
                                      : Colors.white54,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
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
                      Text(
                        safeAchievementDescription,
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
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 6,
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
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 6,
              children: [
                TextButton.icon(
                  onPressed: shouldMaskDetails
                      ? null
                      : () {
                          // Only navigate if we have all required V2 composite keys
                          if (widget.platformId == null ||
                              widget.platformGameId == null ||
                              achievement['platform_achievement_id'] == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Comments not available for this achievement',
                                ),
                              ),
                            );
                            return;
                          }

                          final achievementRef = AchievementRef(
                            gameRef: GameRef(
                              platformId: widget.platformId!,
                              platformGameId: widget.platformGameId!,
                            ),
                            platformAchievementId:
                                achievement['platform_achievement_id']
                                    .toString(),
                          );
                          context.push(achievementRef.location);
                        },
                  icon: const Icon(Icons.chat_bubble_outline, size: 14),
                  label: const Text(
                    'Tips/Comments',
                    style: TextStyle(fontSize: 10),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: CyberpunkTheme.neonCyan,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 4),
                Builder(
                  builder: (context) {
                    final status = ref.watch(achievementCreditsProvider);
                    final creditBadge = status.asData?.value.badgeText ?? '…';

                    return TextButton.icon(
                      onPressed:
                          shouldMaskDetails ||
                              ref.watch(currentUserIdProvider) == null
                          ? null
                          : () => _showAIGuideDialog(
                              context,
                              shouldMaskDetails
                                  ? {
                                      ...achievement,
                                      'name': safeAchievementName,
                                      'description': safeAchievementDescription,
                                    }
                                  : achievement,
                            ),
                      icon: const Icon(Icons.lightbulb_outline, size: 14),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('AI Help', style: TextStyle(fontSize: 10)),
                          const SizedBox(width: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 3,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: CyberpunkTheme.neonPurple.withValues(
                                alpha: 0.3,
                              ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    );
                  },
                ),
              ],
            ),
            if (!isEarned) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed:
                      shouldMaskDetails ||
                          ref.watch(currentUserIdProvider) == null
                      ? null
                      : () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => CreateTrophyRequestDialog(
                              gameId: widget.platformGameId ?? '',
                              gameTitle: widget.gameName,
                              achievementId: achievement['id'].toString(),
                              achievementName: safeAchievementName,
                              platform:
                                  widget.platform.toLowerCase().startsWith('ps')
                                  ? 'psn'
                                  : widget.platform.toLowerCase().startsWith(
                                      'xbox',
                                    )
                                  ? 'xbox'
                                  : 'steam',
                            ),
                          );

                          if (result == true && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'View your request in Co-op Partners',
                                ),
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
                  label: const Text(
                    'Find Partner',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: CyberpunkTheme.neonCyan,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
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
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
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

  Future<void> _showAIGuideDialog(
    BuildContext context,
    Map<String, dynamic> achievement,
  ) async {
    final achievementName =
        achievement['name'] as String? ?? 'Unknown Achievement';
    final achievementDescription = achievement['description'] as String? ?? '';

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0E27).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: CyberpunkTheme.neonPurple.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: CyberpunkTheme.neonPurple.withValues(alpha: 0.3),
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
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
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
                  platformId: widget.platformId,
                  platformGameId: widget.platformGameId,
                  platformAchievementId: achievement['platform_achievement_id']
                      ?.toString(),
                  onCreditConsumed: _refreshAICreditBadge,
                  onNoCredits: () async {
                    if (!context.mounted) return;
                    AnalyticsService().logCustomEvent(
                      eventName: 'premium_trigger_impression',
                      parameters: {'source': 'ai_limit'},
                    );
                    _showAIPurchaseDialog(context);
                  },
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

  Future<void> _showAIPurchaseDialog(BuildContext context) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const AICreditShopScreen()));
    if (mounted) _refreshAICreditBadge();
  }
}

/// Widget that displays AI-generated achievement guide with streaming support
class _AIGuideContent extends ConsumerStatefulWidget {
  final String gameTitle;
  final String achievementName;
  final String achievementDescription;
  final String platform;
  final int? platformId;
  final String? platformGameId;
  final String? platformAchievementId;
  final VoidCallback? onCreditConsumed;
  final VoidCallback? onNoCredits;

  const _AIGuideContent({
    required this.gameTitle,
    required this.achievementName,
    required this.achievementDescription,
    required this.platform,
    this.platformId,
    this.platformGameId,
    this.platformAchievementId,
    this.onCreditConsumed,
    this.onNoCredits,
  });

  @override
  ConsumerState<_AIGuideContent> createState() => _AIGuideContentState();
}

class _AIGuideContentState extends ConsumerState<_AIGuideContent> {
  AchievementGuideService get _guideService =>
      ref.read(achievementGuideServiceProvider);
  String _guideText = '';
  bool _isLoading = false;
  String? _error;

  bool _hasYouTubeLink(String text) {
    final lower = text.toLowerCase();
    return lower.contains('youtube.com') || lower.contains('youtu.be');
  }

  @override
  void initState() {
    super.initState();
    _loadGuide();
  }

  Future<void> _loadGuide() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    // Reusing a saved guide does not make a paid generation request.
    // Check if we already have a cached guide in the database
    final cached = await _checkCachedGuide();
    if (!mounted) return;
    if (cached != null) {
      statusxpLog('✅ Loaded guide from cache (${cached.length} chars)');
      setState(() {
        _guideText = cached;
      });

      // Search for YouTube video even for cached guides (if not already included)
      if (!_hasYouTubeLink(_guideText)) {
        statusxpLog('🎥 Cached guide has no YouTube link - searching...');
        await _appendYouTubeLink();
        // Update database with YouTube link if found
        if (_hasYouTubeLink(_guideText)) {
          await _saveGuideToDatabase(_guideText);
        }
      } else {
        statusxpLog('✅ Cached guide already has YouTube link');
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    statusxpLog('🤖 No cached guide - generating new one with AI...');

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
        if (!mounted) return;
        widget.onCreditConsumed?.call();
        setState(() {
          _guideText += chunk;
        });
      }

      statusxpLog(
        '✅ AI guide generation complete - now searching for YouTube video...',
      );

      // Search for YouTube video and append to guide
      await _appendYouTubeLink();

      statusxpLog('✅ YouTube search complete - now saving to database...');

      // Save to database
      await _saveGuideToDatabase(_guideText);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      statusxpLog('❌ Error in guide generation flow: $e');
      if (!mounted) return;
      if (e is GuideCreditsUnavailable) widget.onNoCredits?.call();
      widget.onCreditConsumed?.call();
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _appendYouTubeLink() async {
    try {
      statusxpLog(
        '🎥 Starting YouTube search for: "${widget.gameTitle}" - "${widget.achievementName}"',
      );
      final youtubeService = YouTubeSearchService();
      final videoUrl = await youtubeService.searchAchievementGuide(
        gameTitle: widget.gameTitle,
        achievementName: widget.achievementName,
      );

      if (!mounted) return;
      if (videoUrl != null) {
        statusxpLog('✅ YouTube video found: $videoUrl');
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
        statusxpLog('⚠️ No YouTube video found');
      }
    } catch (e) {
      statusxpLog('❌ YouTube search error: $e');
      // Continue without YouTube link if it fails
    }
  }

  Future<String?> _checkCachedGuide() async {
    if (widget.platformId == null ||
        widget.platformGameId == null ||
        widget.platformAchievementId == null) {
      statusxpLog('❌ Missing composite key - cannot check cached guide');
      return null;
    }

    try {
      statusxpLog(
        '🔍 Checking cache for achievement key: '
        'platform=${widget.platformId}, '
        'game=${widget.platformGameId}, '
        'achievement=${widget.platformAchievementId}',
      );
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('achievements')
          .select('ai_guide, ai_guide_generated_at')
          .eq('platform_id', widget.platformId!)
          .eq('platform_game_id', widget.platformGameId!)
          .eq('platform_achievement_id', widget.platformAchievementId!)
          .maybeSingle();

      if (response == null) {
        statusxpLog('⚠️ No achievement row found for composite key');
        return null;
      }

      statusxpLog('📊 Database response: $response');
      final cachedGuide = response['ai_guide'] as String?;
      final generatedAt = response['ai_guide_generated_at'] as String?;

      if (cachedGuide != null && cachedGuide.isNotEmpty) {
        statusxpLog(
          '✅ Found cached guide (${cachedGuide.length} chars) generated at: $generatedAt',
        );
        return cachedGuide;
      } else {
        statusxpLog(
          '⚠️ No cached guide found - ai_guide: $cachedGuide, generated_at: $generatedAt',
        );
        return null;
      }
    } catch (e) {
      statusxpLog('❌ Error checking cached guide: $e');
      return null;
    }
  }

  Future<void> _saveGuideToDatabase(String guide) async {
    if (widget.platformId == null ||
        widget.platformGameId == null ||
        widget.platformAchievementId == null) {
      statusxpLog('❌ Cannot save guide - missing composite key');
      return;
    }

    try {
      statusxpLog(
        '💾 Saving guide for achievement key: '
        'platform=${widget.platformId}, '
        'game=${widget.platformGameId}, '
        'achievement=${widget.platformAchievementId}',
      );
      final supabase = Supabase.instance.client;

      // First verify the record exists
      statusxpLog(
        '🔍 Verifying achievement exists in database (composite key)',
      );
      final existsCheck = await supabase
          .from('achievements')
          .select('platform_achievement_id, name')
          .eq('platform_id', widget.platformId!)
          .eq('platform_game_id', widget.platformGameId!)
          .eq('platform_achievement_id', widget.platformAchievementId!)
          .maybeSingle();

      if (existsCheck == null) {
        statusxpLog('❌ Achievement does not exist for composite key');
        return;
      }
      statusxpLog(
        '✅ Achievement exists: ${existsCheck['name']} '
        '(platform_achievement_id: ${existsCheck['platform_achievement_id']})',
      );

      statusxpLog('💾 Attempting to update guide (${guide.length} chars)');

      // Try simple update first without select
      await supabase
          .from('achievements')
          .update({
            'ai_guide': guide,
            'ai_guide_generated_at': DateTime.now().toIso8601String(),
          })
          .eq('platform_id', widget.platformId!)
          .eq('platform_game_id', widget.platformGameId!)
          .eq('platform_achievement_id', widget.platformAchievementId!);

      statusxpLog('📝 Update query executed, verifying if it worked...');

      // Verify the update worked by querying the record again
      final verification = await supabase
          .from('achievements')
          .select('platform_achievement_id, ai_guide, ai_guide_generated_at')
          .eq('platform_id', widget.platformId!)
          .eq('platform_game_id', widget.platformGameId!)
          .eq('platform_achievement_id', widget.platformAchievementId!)
          .single();

      final savedGuide = verification['ai_guide'] as String?;
      final savedAt = verification['ai_guide_generated_at'] as String?;

      if (savedGuide != null && savedGuide.isNotEmpty) {
        statusxpLog(
          '✅ Update successful! Guide saved (${savedGuide.length} chars) at $savedAt',
        );
      } else {
        statusxpLog('❌ Update failed - guide is still null/empty');
        statusxpLog('🔍 Full verification result: $verification');
      }
    } catch (e) {
      statusxpLog('❌ Error saving guide: $e');
      // Also print the stack trace to see more details
      statusxpLog('Stack trace: ${StackTrace.current}');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: CyberpunkTheme.neonPink,
              size: 48,
            ),
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
                    valueColor: AlwaysStoppedAnimation<Color>(
                      CyberpunkTheme.neonPurple,
                    ),
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
                      valueColor: AlwaysStoppedAnimation<Color>(
                        CyberpunkTheme.neonPurple,
                      ),
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
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
      );
    }

    // Build text with clickable links
    final spans = <InlineSpan>[];
    int lastIndex = 0;

    for (final match in matches) {
      // Add text before the URL
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: _guideText.substring(lastIndex, match.start),
            style: const TextStyle(color: Colors.white),
          ),
        );
      }

      // Add clickable URL
      final url = match.group(0)!;
      spans.add(
        WidgetSpan(
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
        ),
      );

      lastIndex = match.end;
    }

    // Add remaining text after last URL
    if (lastIndex < _guideText.length) {
      spans.add(
        TextSpan(
          text: _guideText.substring(lastIndex),
          style: const TextStyle(color: Colors.white),
        ),
      );
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 14, height: 1.5),
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
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white70),
            ),
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
      } else {}
    }
  }
}
