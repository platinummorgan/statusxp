import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/analytics_data.dart';
import 'package:statusxp/data/repositories/analytics_repository.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/ui/widgets/charts/trophy_timeline_chart.dart';
import 'package:statusxp/ui/widgets/charts/platform_pie_chart.dart';
import 'package:statusxp/ui/widgets/charts/rarity_bar_chart.dart';
import 'package:statusxp/ui/widgets/charts/trophy_type_chart.dart';
import 'package:statusxp/ui/widgets/charts/monthly_activity_chart.dart';
import 'package:statusxp/ui/widgets/charts/daily_trend_chart.dart';
import 'package:statusxp/ui/widgets/charts/platform_split_window_chart.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:go_router/go_router.dart';

/// Provider for analytics repository
final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AnalyticsRepository(client);
});

/// Provider for analytics data
final analyticsDataProvider = FutureProvider<AnalyticsData>((ref) async {
  final repository = ref.watch(analyticsRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    throw Exception('Not authenticated');
  }

  return repository.getAnalyticsData(userId);
});

/// Premium Analytics Screen
///
/// Shows comprehensive gaming analytics with beautiful charts
class PremiumAnalyticsScreen extends ConsumerStatefulWidget {
  const PremiumAnalyticsScreen({super.key});

  @override
  ConsumerState<PremiumAnalyticsScreen> createState() =>
      _PremiumAnalyticsScreenState();
}

class _PremiumAnalyticsScreenState
    extends ConsumerState<PremiumAnalyticsScreen> {
  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isChecking = true;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    final isPremium = await _subscriptionService.isPremiumActive();
    if (mounted) {
      setState(() {
        _isPremium = isPremium;
        _isChecking = false;
      });

      // If not premium, show upgrade dialog
      if (!isPremium) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPremiumRequiredDialog();
        });
      }
    }
  }

  void _showPremiumRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentPrimary.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.analytics, color: accentPrimary),
            SizedBox(width: 12),
            Text('Premium Feature'),
          ],
        ),
        content: const Text(
          'Analytics is a Premium feature that provides comprehensive insights into your gaming journey with beautiful charts and statistics.\n\nUpgrade to Premium to unlock:\n• Trophy timeline tracking\n• Platform distribution analysis\n• Rarity breakdown charts\n• Monthly activity reports\n• And much more!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.pop(); // Close dialog
              context.pop(); // Return to dashboard
            },
            child: const Text('Maybe Later'),
          ),
          FilledButton(
            onPressed: () {
              context.pop(); // Close dialog
              context.pop(); // Return to dashboard
              context.push('/premium-subscription');
            },
            style: FilledButton.styleFrom(backgroundColor: accentPrimary),
            child: const Text('Upgrade to Premium'),
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

    final analyticsAsync = ref.watch(analyticsDataProvider);

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
            const Text(
              'Analytics',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentPrimary.withValues(alpha: 0.25),
                    accentSecondary.withValues(alpha: 0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: accentPrimary.withValues(alpha: 0.55),
                ),
              ),
              child: const Text(
                'PREMIUM',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: accentPrimary,
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
            analyticsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: accentPrimary),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Failed to load analytics',
                        style: TextStyle(color: textPrimary, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(color: textMuted, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              data: (analytics) => _buildAnalyticsContent(context, analytics),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsContent(BuildContext context, AnalyticsData analytics) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          // Invalidate provider to force refresh
          ref.invalidate(analyticsDataProvider);
          // Wait for new data
          await ref.read(analyticsDataProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChartSection(
                'Recent Trend',
                'Daily achievements over the last 30 days',
                DailyTrendChart(data: analytics.dailyTrendData),
                accent: accentPrimary,
              ),
              const SizedBox(height: 24),
              _buildChartSection(
                'Platform Split',
                'Compare short-term and monthly platform focus',
                PlatformSplitWindowChart(data: analytics.platformSplitTrend),
                accent: accentSuccess,
              ),
              const SizedBox(height: 24),
              _buildChartSection(
                'Seasonal Pace',
                'Where you stand in active weekly and monthly races',
                _buildSeasonalPaceSection(analytics.seasonalPaceData),
                accent: accentSecondary,
              ),
              const SizedBox(height: 24),
              _buildChartSection(
                'Trophy & Achievement Journey',
                'Your progress across PSN, Xbox, and Steam over time',
                TrophyTimelineChart(data: analytics.timelineData),
                accent: accentPrimary,
              ),
              const SizedBox(height: 24),
              _buildChartSection(
                'Monthly Activity',
                'Trophies and achievements earned per month',
                MonthlyActivityChart(data: analytics.monthlyActivity),
                accent: accentWarning,
              ),
              const SizedBox(height: 24),
              _buildChartSection(
                'Platform Distribution',
                'Where you trophy hunt most',
                PlatformPieChart(data: analytics.platformDistribution),
                accent: accentSuccess,
              ),
              const SizedBox(height: 24),
              _buildChartSection(
                'Rarity Distribution',
                'How rare are your trophies?',
                RarityBarChart(data: analytics.rarityDistribution),
                accent: accentSecondary,
              ),
              const SizedBox(height: 24),
              if (analytics.trophyTypeBreakdown.total > 0) ...[
                _buildChartSection(
                  'Trophy Types (PSN)',
                  'Bronze, Silver, Gold, Platinum',
                  TrophyTypeChart(data: analytics.trophyTypeBreakdown),
                  accent: accentPrimary,
                ),
                const SizedBox(height: 80),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartSection(
    String title,
    String subtitle,
    Widget chart, {
    Color accent = accentPrimary,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: accent,
              shadows: CyberpunkTheme.neonGlow(color: accent, blurRadius: 4),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(height: 20),
          chart,
        ],
      ),
    );
  }

  Widget _buildSeasonalPaceSection(SeasonalPaceData data) {
    return Column(
      children: [
        _buildSeasonalPaceCard(data.weekly),
        const SizedBox(height: 12),
        _buildSeasonalPaceCard(data.monthly),
      ],
    );
  }

  Widget _buildSeasonalPaceCard(SeasonalPaceSnapshot snapshot) {
    final isWeekly = snapshot.periodLabel.toLowerCase().contains('week');
    final accent = isWeekly ? accentPrimary : accentSecondary;
    final rankText = snapshot.currentRank > 0
        ? '#${snapshot.currentRank} of ${snapshot.totalPlayers}'
        : 'Unranked';
    final progress = (snapshot.progressPercent / 100).clamp(0, 1).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.12),
            Colors.black.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                snapshot.periodLabel,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                rankText,
                style: const TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _paceStat('Gain', snapshot.currentGain.toString()),
              _paceStat('Projected', snapshot.projectedGain.toString()),
              _paceStat('Gap to #1', snapshot.gapToFirst.toString()),
              _paceStat('Day', '${snapshot.daysElapsed}/${snapshot.daysTotal}'),
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

  Widget _paceStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: textMuted,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
