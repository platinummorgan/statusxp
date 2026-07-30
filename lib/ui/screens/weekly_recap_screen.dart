import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:statusxp/domain/weekly_recap.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/services/referral_prompt_service.dart';
import 'package:statusxp/state/weekly_recap_provider.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class WeeklyRecapScreen extends ConsumerStatefulWidget {
  const WeeklyRecapScreen({super.key});

  @override
  ConsumerState<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends ConsumerState<WeeklyRecapScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    AnalyticsService().logCustomEvent(eventName: 'weekly_recap_viewed');
  }

  Future<void> _share(WeeklyRecap recap) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    HapticFeedback.lightImpact();
    AnalyticsService().logCustomEvent(
      eventName: 'weekly_recap_shared',
      parameters: {
        'unlocks': recap.unlocks,
        'statusxp_gained': recap.statusXpGained,
      },
    );
    final message =
        'My StatusXP week: +${recap.statusXpGained} StatusXP, '
        '${recap.unlocks} unlocks, ${recap.gamesProgressed} games progressed 🎮';
    try {
      if (kIsWeb) {
        await Share.share(message);
      } else {
        final bytes = await _screenshotController.capture(
          pixelRatio: 2,
          delay: const Duration(milliseconds: 50),
        );
        if (bytes == null) throw Exception('Capture failed');
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/statusxp_weekly_recap.png');
        await file.writeAsBytes(bytes);
        await Share.shareXFiles([XFile(file.path)], text: message);
      }
      if (mounted) {
        await ReferralPromptService().showIfEligible(
          context,
          source: 'weekly_recap_share',
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to share your recap right now')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _openPlayNext(WeeklyRecap recap) {
    final next = recap.playNext;
    if (next == null) return;
    AnalyticsService().logCustomEvent(
      eventName: 'weekly_recap_action',
      parameters: {'action': 'play_next', 'game': next.gameTitle},
    );
    context.push(
      Uri(
        path: '/game/${next.platformGameId}/achievements',
        queryParameters: {
          'name': next.gameTitle,
          'platform_id': next.platformId.toString(),
          'platform_game_id': next.platformGameId,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recapAsync = ref.watch(weeklyRecapProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        title: const Text('YOUR WEEK IN STATUSXP'),
        actions: [
          recapAsync.maybeWhen(
            data: (recap) => IconButton(
              tooltip: 'Share recap',
              onPressed: _sharing ? null : () => _share(recap),
              icon: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: recapAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) =>
            _ErrorState(onRetry: () => ref.invalidate(weeklyRecapProvider)),
        data: (recap) => RefreshIndicator(
          onRefresh: () async => ref.refresh(weeklyRecapProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
            children: [
              Screenshot(
                controller: _screenshotController,
                child: _ShareCard(recap: recap),
              ),
              const SizedBox(height: 22),
              if (recap.topGame != null)
                _DetailCard(
                  icon: Icons.trending_up,
                  eyebrow: 'BIGGEST PROGRESS',
                  title: recap.topGame!.gameName,
                  detail:
                      '+${recap.topGame!.periodGain} StatusXP • ${recap.topGame!.earnedCount} unlocks',
                ),
              if (recap.topGame != null) const SizedBox(height: 14),
              if (recap.rarestUnlock != null)
                _DetailCard(
                  icon: Icons.diamond_outlined,
                  eyebrow: 'RAREST UNLOCK THIS WEEK',
                  title: recap.rarestUnlock!.trophyName,
                  detail:
                      '${recap.rarestUnlock!.gameName} • ${recap.rarestUnlock!.rarity.toStringAsFixed(1)}% rarity',
                ),
              if (recap.rarestUnlock != null) const SizedBox(height: 14),
              if (recap.playNext != null)
                _PlayNextCard(recap: recap, onTap: () => _openPlayNext(recap)),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: _sharing ? null : () => _share(recap),
                icon: const Icon(Icons.ios_share),
                label: const Text('SHARE MY WEEK'),
              ),
              const SizedBox(height: 18),
              _PremiumTeaser(
                onTap: () {
                  AnalyticsService().logCustomEvent(
                    eventName: 'weekly_recap_action',
                    parameters: {'action': 'premium_insights'},
                  );
                  context.push('/premium-subscription?source=weekly_recap');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.recap});

  final WeeklyRecap recap;

  @override
  Widget build(BuildContext context) {
    final dates =
        '${DateFormat.MMMd().format(recap.periodStart.toLocal())} – '
        '${DateFormat.MMMd().format(recap.periodEnd.subtract(const Duration(days: 1)).toLocal())}';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF090D25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CyberpunkTheme.neonCyan, width: 1.5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CyberpunkTheme.neonPurple.withValues(alpha: 0.22),
            const Color(0xFF090D25),
            CyberpunkTheme.neonCyan.withValues(alpha: 0.10),
          ],
        ),
      ),
      child: Column(
        children: [
          const Text(
            'STATUSXP',
            style: TextStyle(
              color: CyberpunkTheme.neonCyan,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 5),
          Text(dates, style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),
          Text(
            '+${recap.statusXpGained}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'STATUSXP THIS WEEK',
            style: TextStyle(
              color: CyberpunkTheme.neonCyan,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              _Metric(value: '${recap.unlocks}', label: 'Unlocks'),
              _Metric(value: '${recap.gamesProgressed}', label: 'Games'),
              _Metric(value: '${recap.currentStreak}', label: 'Day streak'),
            ],
          ),
          if (recap.topGame != null) ...[
            const SizedBox(height: 20),
            Text(
              'TOP GAME • ${recap.topGame!.gameName}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.detail,
  });
  final IconData icon;
  final String eyebrow;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0A0E27),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Icon(icon, color: CyberpunkTheme.neonCyan, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: const TextStyle(
                      color: CyberpunkTheme.neonCyan,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(detail, style: const TextStyle(color: Colors.white60)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayNextCard extends StatelessWidget {
  const _PlayNextCard({required this.recap, required this.onTap});
  final WeeklyRecap recap;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final next = recap.playNext!;
    return Card(
      color: CyberpunkTheme.neonPurple.withValues(alpha: 0.15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const Icon(
                Icons.play_circle_fill,
                color: CyberpunkTheme.neonPurple,
                size: 38,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PLAY THIS NEXT',
                      style: TextStyle(
                        color: CyberpunkTheme.neonPurple,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      next.gameTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${next.completionPercentage.round()}% complete • ${next.remainingAchievements} remaining',
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumTeaser extends StatelessWidget {
  const _PremiumTeaser({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      tileColor: CyberpunkTheme.neonPurple.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: const Icon(Icons.insights, color: CyberpunkTheme.neonPurple),
      title: const Text(
        'See your deeper trends',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
      ),
      subtitle: const Text(
        'Premium adds pace coaching, goals, and achievement radar.',
        style: TextStyle(color: Colors.white60),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: Colors.white54, size: 48),
            const SizedBox(height: 14),
            const Text(
              'Your recap could not be loaded yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 17),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
