import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/services/premium_activation_service.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/theme/colors.dart';

class PremiumActivationChecklist extends StatefulWidget {
  const PremiumActivationChecklist({required this.userId, super.key});
  final String userId;

  @override
  State<PremiumActivationChecklist> createState() =>
      _PremiumActivationChecklistState();
}

class PremiumFeatureActivationMarker extends StatefulWidget {
  const PremiumFeatureActivationMarker({
    required this.task,
    required this.child,
    super.key,
  });
  final PremiumActivationTask task;
  final Widget child;

  @override
  State<PremiumFeatureActivationMarker> createState() =>
      _PremiumFeatureActivationMarkerState();
}

class _PremiumFeatureActivationMarkerState
    extends State<PremiumFeatureActivationMarker> {
  @override
  void initState() {
    super.initState();
    _markIfPremium();
  }

  Future<void> _markIfPremium() async {
    if (await SubscriptionService().isPremiumActive()) {
      await PremiumActivationService().completeCurrentUser(widget.task);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _PremiumActivationChecklistState
    extends State<PremiumActivationChecklist> {
  final _service = PremiumActivationService();
  Set<PremiumActivationTask> _completed = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final completed = await _service.completed(widget.userId);
    if (!mounted) return;
    setState(() => _completed = completed);
  }

  Future<void> _open(PremiumActivationTask task, String route) async {
    await _service.complete(widget.userId, task);
    await _load();
    AnalyticsService().logCustomEvent(
      eventName: 'premium_activation_task_opened',
      parameters: {'task': task.name},
    );
    if (mounted) context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = [
      (
        PremiumActivationTask.analytics,
        'Discover your deeper trends',
        '/analytics',
        Icons.analytics,
      ),
      (
        PremiumActivationTask.radar,
        'Find your fastest achievement wins',
        '/achievement-radar',
        Icons.radar,
      ),
      (
        PremiumActivationTask.goal,
        'Set your first progress goal',
        '/goals-pace',
        Icons.flag,
      ),
      (
        PremiumActivationTask.premiumSync,
        'Use your faster Premium sync',
        '/sync-intelligence',
        Icons.sync,
      ),
    ];
    final progress = _completed.length / tasks.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentPrimary.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ACTIVATE YOUR PREMIUM VALUE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${_completed.length}/${tasks.length}',
                style: const TextStyle(
                  color: accentPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, minHeight: 5),
          const SizedBox(height: 12),
          for (final item in tasks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => _open(item.$1, item.$3),
              leading: Icon(
                _completed.contains(item.$1) ? Icons.check_circle : item.$4,
                color: _completed.contains(item.$1)
                    ? accentSuccess
                    : accentPrimary,
              ),
              title: Text(
                item.$2,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: const Icon(Icons.chevron_right, color: textMuted),
            ),
          if (_completed.length == tasks.length)
            const Text(
              'You have explored the core Premium experience. Keep the momentum going!',
              style: TextStyle(
                color: accentSuccess,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
