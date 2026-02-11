import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/data/repositories/sync_intelligence_repository.dart';
import 'package:statusxp/domain/sync_intelligence_data.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';

final syncIntelligenceRepositoryProvider = Provider<SyncIntelligenceRepository>(
  (ref) {
    final client = ref.watch(supabaseClientProvider);
    return SyncIntelligenceRepository(client);
  },
);

final syncIntelligenceDataProvider = FutureProvider.autoDispose<SyncIntelligenceData>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    throw Exception('Not authenticated');
  }
  final repository = ref.watch(syncIntelligenceRepositoryProvider);
  return repository.getSyncIntelligence(userId);
});

class PremiumSyncIntelligenceScreen extends ConsumerStatefulWidget {
  const PremiumSyncIntelligenceScreen({super.key});

  @override
  ConsumerState<PremiumSyncIntelligenceScreen> createState() =>
      _PremiumSyncIntelligenceScreenState();
}

class _PremiumSyncIntelligenceScreenState
    extends ConsumerState<PremiumSyncIntelligenceScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  final DateFormat _dateFormat = DateFormat('MMM d, h:mm a');
  bool _isChecking = true;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    final isPremium = await _subscriptionService.isPremiumActive();
    if (!mounted) return;

    setState(() {
      _isPremium = isPremium;
      _isChecking = false;
    });

    if (!isPremium) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _showPremiumRequiredDialog(),
      );
    } else {
      // Ensure diagnostics are always freshly fetched when opening the screen.
      ref.invalidate(syncIntelligenceDataProvider);
    }
  }

  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceLight,
        title: const Row(
          children: [
            Icon(Icons.workspace_premium, color: accentPrimary),
            SizedBox(width: 10),
            Text('Premium Feature'),
          ],
        ),
        content: const Text(
          'Sync Intelligence is available to Premium users. Upgrade to unlock sync diagnostics and recommendations.',
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

    final dataAsync = ref.watch(syncIntelligenceDataProvider);

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: surfaceLight,
        title: const Text('Sync Intelligence'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: dataAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: accentPrimary),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load sync diagnostics\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: textSecondary),
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(syncIntelligenceDataProvider);
            await ref.read(syncIntelligenceDataProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _recommendationCard(data.recommendation),
              const SizedBox(height: 16),
              _summaryCard(data),
              const SizedBox(height: 16),
              const Text(
                'Platform Health',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              ...data.platforms.map(
                (platform) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _platformCard(platform),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'Top Import Gaps',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          backgroundColor: surfaceLight,
                          title: const Text(
                            'What This Means',
                            style: TextStyle(color: textPrimary),
                          ),
                          content: const Text(
                            'Import Gaps are diagnostics for platform-to-DB ingestion only. '
                            'They do not mean your profile completion is wrong on Xbox/PSN/Steam.',
                            style: TextStyle(color: textSecondary, height: 1.4),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              child: const Text('Got it'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Icon(
                      Icons.info_outline,
                      color: textMuted,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'API = unlocked on platform. Imported = stored in app DB.',
                style: TextStyle(color: textMuted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              if (data.topMissingGames.isEmpty)
                _emptyCard('No import gaps detected.')
              else
                ...data.topMissingGames
                    .take(12)
                    .map(
                      (game) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _missingGameRow(game),
                      ),
                    ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recommendationCard(SyncRecommendation recommendation) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            accentPrimary.withOpacity(0.22),
            accentSecondary.withOpacity(0.16),
          ],
        ),
        border: Border.all(color: accentPrimary.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Next Best Sync Target',
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recommendation.platform == 'none'
                ? 'No linked platform'
                : recommendation.platform.toUpperCase(),
            style: const TextStyle(
              color: accentPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            recommendation.reason,
            style: const TextStyle(color: textSecondary, height: 1.3),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _pill(
                'Est. unimported score',
                recommendation.estimatedGapScore.toString(),
              ),
              _pill(
                'Est. unimported achv.',
                recommendation.estimatedGapAchievements.toString(),
              ),
              if (!recommendation.canSyncNow && recommendation.waitSeconds > 0)
                _pill('Cooldown', _formatWait(recommendation.waitSeconds)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(SyncIntelligenceData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        children: [
          _summaryStat(
            'Unimported Score',
            data.totalMissingGapScore.toString(),
          ),
          _summaryStat(
            'Unimported Achievements',
            data.totalMissingGapAchievements.toString(),
          ),
          _summaryStat(
            'Platforms Linked',
            data.platforms
                .where((platform) => platform.linked)
                .length
                .toString(),
          ),
          _summaryStat('Games Flagged', data.topMissingGames.length.toString()),
        ],
      ),
    );
  }

  Widget _platformCard(PlatformSyncIntelligence platform) {
    final errorText = (platform.lastError ?? '').toLowerCase();
    final hasAuthError =
        errorText.contains('token') ||
        errorText.contains('auth') ||
        errorText.contains('oauth') ||
        errorText.contains('invalid_grant') ||
        errorText.contains('expired') ||
        errorText.contains('refresh');

    // Color status by observed sync health, not raw token timestamp.
    final danger = platform.syncStatus == 'error';
    final warning = !danger && platform.staleSync;
    final accent = danger
        ? Colors.redAccent
        : warning
        ? accentWarning
        : accentSuccess;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                platform.displayName,
                style: const TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  platform.linked ? platform.syncStatus : 'not_linked',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                platform.canSyncNow
                    ? 'Ready'
                    : _formatWait(platform.waitSeconds),
                style: TextStyle(
                  color: platform.canSyncNow ? accentSuccess : textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _kv('Unimported Score', platform.estimatedGapScore.toString()),
              _kv(
                'Unimported Achievements',
                platform.estimatedGapAchievements.toString(),
              ),
              _kv(
                'Last Sync',
                platform.lastSyncAt == null
                    ? 'Never'
                    : _dateFormat.format(platform.lastSyncAt!.toLocal()),
              ),
              if (platform.tokenExpiresAt != null)
                _kv(
                  'Token (advisory)',
                  platform.tokenExpired && (danger || hasAuthError)
                      ? 'Expired'
                      : _dateFormat.format(platform.tokenExpiresAt!.toLocal()),
                ),
            ],
          ),
          if ((platform.lastError ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Error: ${platform.lastError}',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
          if (platform.syncReason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              platform.syncReason,
              style: const TextStyle(color: textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _missingGameRow(MissingGameInsight game) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
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
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                game.platform.toUpperCase(),
                style: const TextStyle(
                  color: accentPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _kv('Unimported score', game.estimatedMissingScore.toString()),
              _kv(
                'Unimported unlocked',
                game.estimatedMissingAchievements.toString(),
              ),
              _kv('API unlocked', game.apiEarnedCount.toString()),
              _kv('Imported', game.dbEarnedCount.toString()),
            ],
          ),
          if (game.apiEarnedCount > 0 && game.dbEarnedCount == 0) ...[
            const SizedBox(height: 8),
            const Text(
              'Unlocked on platform, but not imported into app DB yet for this title.',
              style: TextStyle(color: accentWarning, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(text, style: const TextStyle(color: textSecondary)),
    );
  }

  Widget _summaryStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: textMuted, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _pill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
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

  String _formatWait(int waitSeconds) {
    if (waitSeconds <= 0) return 'Ready';
    final hours = waitSeconds ~/ 3600;
    final minutes = (waitSeconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '${waitSeconds}s';
  }
}
