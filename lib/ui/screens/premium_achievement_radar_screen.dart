import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/domain/premium_features_data.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/state/premium_features_providers.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/theme/colors.dart';

class PremiumAchievementRadarScreen extends ConsumerStatefulWidget {
  const PremiumAchievementRadarScreen({super.key});

  @override
  ConsumerState<PremiumAchievementRadarScreen> createState() =>
      _PremiumAchievementRadarScreenState();
}

class _PremiumAchievementRadarScreenState
    extends ConsumerState<PremiumAchievementRadarScreen> {
  static const String _hiddenGamesKeyPrefix = 'premium_radar_hidden_games_';

  final SubscriptionService _subscriptionService = SubscriptionService();
  final DateFormat _dateFormat = DateFormat('MMM d, y');
  bool _isChecking = true;
  bool _isPremium = false;
  Set<String> _hiddenGameKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadHiddenGames();
    await _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    final isPremium = await _subscriptionService.isPremiumActive();
    if (!mounted) return;

    setState(() {
      _isPremium = isPremium;
      _isChecking = false;
    });

    if (!isPremium) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPremiumRequiredDialog();
      });
    } else {
      ref.invalidate(achievementRadarDataProvider);
    }
  }

  String _storageKey() {
    final userId = ref.read(currentUserIdProvider) ?? 'anonymous';
    return '$_hiddenGamesKeyPrefix$userId';
  }

  String _gameKey(RadarGameInsight game) {
    return '${game.platformId}:${game.platformGameId}';
  }

  Future<void> _loadHiddenGames() async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList(_storageKey()) ?? const <String>[];
    if (!mounted) return;
    setState(() {
      _hiddenGameKeys = values.toSet();
    });
  }

  Future<void> _persistHiddenGames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey(), _hiddenGameKeys.toList()..sort());
  }

  Future<void> _hideGame(RadarGameInsight game) async {
    final key = _gameKey(game);
    if (_hiddenGameKeys.contains(key)) return;
    setState(() {
      _hiddenGameKeys = {..._hiddenGameKeys, key};
    });
    await _persistHiddenGames();
  }

  Future<void> _unhideKey(String key) async {
    if (!_hiddenGameKeys.contains(key)) return;
    setState(() {
      _hiddenGameKeys = {..._hiddenGameKeys}..remove(key);
    });
    await _persistHiddenGames();
  }

  Future<void> _unhideAll() async {
    if (_hiddenGameKeys.isEmpty) return;
    setState(() {
      _hiddenGameKeys = <String>{};
    });
    await _persistHiddenGames();
  }

  void _showPremiumRequiredDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceLight,
        title: const Row(
          children: [
            Icon(Icons.radar, color: accentPrimary),
            SizedBox(width: 10),
            Text('Premium Feature'),
          ],
        ),
        content: const Text(
          'Achievement Radar is available to Premium users.',
          style: TextStyle(color: textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
              context.pop();
            },
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () {
              context.pop();
              context.push('/premium-subscription');
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        backgroundColor: backgroundDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isPremium) {
      return const Scaffold(
        backgroundColor: backgroundDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dataAsync = ref.watch(achievementRadarDataProvider);

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xCC13172B), Color(0xCC1A122B)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        title: Row(
          children: [
            const Text('Achievement Radar'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: accentSecondary.withValues(alpha: 0.2),
                border: Border.all(color: accentPrimary.withValues(alpha: 0.6)),
              ),
              child: const Text(
                'PREMIUM',
                style: TextStyle(
                  color: accentPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -100,
              child: _ambientGlow(
                size: 250,
                color: accentSecondary.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -80,
              child: _ambientGlow(
                size: 260,
                color: accentPrimary.withValues(alpha: 0.14),
              ),
            ),
            dataAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: accentPrimary),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load achievement radar\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: textSecondary),
                  ),
                ),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(achievementRadarDataProvider);
                  await ref.read(achievementRadarDataProvider.future);
                },
                child: Builder(
                  builder: (context) {
                    final nearVisible = _filterVisible(data.nearCompletion);
                    final staleVisible = _filterVisible(data.staleProgress);
                    final potentialVisible = _filterVisible(data.highPotential);
                    final hiddenEntries = _hiddenEntries(data);

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildHiddenGamesBar(hiddenEntries),
                        if (hiddenEntries.isNotEmpty)
                          const SizedBox(height: 12),
                        _buildSection(
                          title: 'Near Completion',
                          subtitle:
                              'High completion games that can be finished quickly.',
                          emptyText: 'No near-completion titles right now.',
                          items: nearVisible,
                          accent: accentSuccess,
                        ),
                        const SizedBox(height: 14),
                        _buildSection(
                          title: 'Stale Progress',
                          subtitle:
                              'Games you started but have not touched recently.',
                          emptyText: 'No stale progress detected.',
                          items: staleVisible,
                          accent: accentWarning,
                        ),
                        const SizedBox(height: 14),
                        _buildSection(
                          title: 'High Potential',
                          subtitle:
                              'Games with the biggest remaining achievement upside.',
                          emptyText: 'No high-potential titles available.',
                          items: potentialVisible,
                          accent: accentPrimary,
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<RadarGameInsight> _filterVisible(List<RadarGameInsight> items) {
    return items
        .where((item) => !_hiddenGameKeys.contains(_gameKey(item)))
        .toList();
  }

  Map<String, RadarGameInsight> _hiddenEntries(AchievementRadarData data) {
    final byKey = <String, RadarGameInsight>{};
    final all = [
      ...data.nearCompletion,
      ...data.staleProgress,
      ...data.highPotential,
    ];
    for (final item in all) {
      final key = _gameKey(item);
      if (_hiddenGameKeys.contains(key) && !byKey.containsKey(key)) {
        byKey[key] = item;
      }
    }
    return byKey;
  }

  Widget _buildHiddenGamesBar(Map<String, RadarGameInsight> hiddenByKey) {
    if (_hiddenGameKeys.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentSecondary.withValues(alpha: 0.16),
            surfaceLight.withValues(alpha: 0.96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentSecondary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: accentSecondary.withValues(alpha: 0.14),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_off, size: 16, color: accentSecondary),
          const SizedBox(width: 8),
          Text(
            'Hidden: ${_hiddenGameKeys.length}',
            style: const TextStyle(
              color: accentSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _showHiddenGamesSheet(hiddenByKey),
            child: const Text('Manage'),
          ),
          if (_hiddenGameKeys.length > 1)
            TextButton(
              onPressed: _unhideAll,
              style: TextButton.styleFrom(
                foregroundColor: accentPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Unhide all'),
            ),
        ],
      ),
    );
  }

  Future<void> _showHiddenGamesSheet(
    Map<String, RadarGameInsight> hiddenByKey,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accentSecondary.withValues(alpha: 0.14), surfaceLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              border: Border.all(
                color: accentSecondary.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  decoration: BoxDecoration(
                    color: textMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 10, 6),
                  child: Row(
                    children: [
                      const Text(
                        'Hidden Games',
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () async {
                          await _unhideAll();
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        child: const Text('Unhide all'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: _hiddenGameKeys.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final key = _hiddenGameKeys.elementAt(index);
                      final entry = hiddenByKey[key];
                      final title = entry?.gameTitle ?? key;
                      final subtitle =
                          entry?.platformLabel ?? 'Unknown platform';
                      return ListTile(
                        tileColor: Colors.black.withValues(alpha: 0.12),
                        title: Text(
                          title,
                          style: const TextStyle(color: textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          subtitle,
                          style: const TextStyle(color: textMuted),
                        ),
                        trailing: IconButton(
                          tooltip: 'Unhide',
                          onPressed: () => _unhideKey(key),
                          icon: const Icon(
                            Icons.visibility,
                            color: accentPrimary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required String emptyText,
    required List<RadarGameInsight> items,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.14),
            surfaceLight.withValues(alpha: 0.95),
            surfaceLight.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: textMuted, fontSize: 12),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(emptyText, style: const TextStyle(color: textSecondary))
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _gameCard(item),
              ),
            ),
        ],
      ),
    );
  }

  Widget _gameCard(RadarGameInsight game) {
    final lastTouched =
        game.lastAchievementAt ?? game.lastPlayedAt ?? game.lastSyncedAt;
    final touchedText = lastTouched == null
        ? 'No recent activity'
        : _dateFormat.format(lastTouched.toLocal());

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentPrimary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  game.gameTitle,
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                game.platformLabel,
                style: const TextStyle(
                  color: accentPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _hideGame(game),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: accentSecondary.withValues(alpha: 0.16),
                    border: Border.all(
                      color: accentSecondary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.visibility_off,
                    size: 16,
                    color: textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _miniStat(
                'Progress',
                '${game.earnedCount}/${game.totalCount} (${game.completionPercent.toStringAsFixed(1)}%)',
              ),
              _miniStat('Remaining', game.remainingCount.toString()),
              _miniStat('Score', game.currentScore.toString()),
              _miniStat('Last activity', touchedText),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ambientGlow({required double size, required Color color}) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: textSecondary, fontSize: 12),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(color: textMuted),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
