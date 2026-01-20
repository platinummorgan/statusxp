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
import 'package:statusxp/services/subscription_service.dart';
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
  ConsumerState<PremiumAnalyticsScreen> createState() => _PremiumAnalyticsScreenState();
}

class _PremiumAnalyticsScreenState extends ConsumerState<PremiumAnalyticsScreen> {
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
          side: BorderSide(color: accentPrimary.withOpacity(0.3)),
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
            style: FilledButton.styleFrom(
              backgroundColor: accentPrimary,
            ),
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
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isPremium) {
      return const Scaffold(
        backgroundColor: backgroundDark,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final analyticsAsync = ref.watch(analyticsDataProvider);

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: surfaceLight,
        title: Row(
          children: [
            const Text(
              'Analytics',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentPrimary.withOpacity(0.3), accentSecondary.withOpacity(0.3)],
                ),
                borderRadius: BorderRadius.circular(4),
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
      body: analyticsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: accentPrimary),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Failed to load analytics',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        data: (analytics) => _buildAnalyticsContent(context, analytics),
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
            children: [            // Debug info card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debug Info',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'User ID: ${ref.read(currentUserIdProvider)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    'Total Trophies: ${analytics.timelineData.totalTrophies}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    'PSN: ${analytics.platformDistribution.psnCount}, Xbox: ${analytics.platformDistribution.xboxCount}, Steam: ${analytics.platformDistribution.steamCount}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    'Timeline Points: PSN=${analytics.timelineData.psnPoints.length}, Xbox=${analytics.timelineData.xboxPoints.length}, Steam=${analytics.timelineData.steamPoints.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    'Rarity Total: ${analytics.rarityDistribution.total}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  if (analytics.timelineData.psnPoints.isNotEmpty || 
                      analytics.timelineData.xboxPoints.isNotEmpty || 
                      analytics.timelineData.steamPoints.isNotEmpty)
                    Text(
                      'First Trophy: ${analytics.timelineData.firstTrophy}',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Trophy Timeline
            _buildChartSection(
              'Trophy & Achievement Journey',
              'Your progress across PSN, Xbox, and Steam over time',
              TrophyTimelineChart(data: analytics.timelineData),
            ),
            const SizedBox(height: 24),

            // Monthly Activity
            _buildChartSection(
              'Monthly Activity',
              'Trophies and achievements earned per month',
              MonthlyActivityChart(data: analytics.monthlyActivity),
            ),
            const SizedBox(height: 24),

            // Platform Distribution
            _buildChartSection(
              'Platform Distribution',
              'Where you trophy hunt most',
              PlatformPieChart(data: analytics.platformDistribution),
            ),
            const SizedBox(height: 24),

            // Rarity Distribution
            _buildChartSection(
              'Rarity Distribution',
              'How rare are your trophies?',
              RarityBarChart(data: analytics.rarityDistribution),
            ),
            const SizedBox(height: 24),

            // Trophy Type Breakdown (PSN)
            if (analytics.trophyTypeBreakdown.total > 0) ...[
              _buildChartSection(
                'Trophy Types (PSN)',
                'Bronze, Silver, Gold, Platinum',
                TrophyTypeChart(data: analytics.trophyTypeBreakdown),
              ),
              const SizedBox(height: 80), // Extra padding at bottom to prevent overflow
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildChartSection(String title, String subtitle, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 20),
          chart,
        ],
      ),
    );
  }
}
