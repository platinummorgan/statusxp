import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/domain/premium_features_data.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/state/premium_features_providers.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/theme/colors.dart';

class PremiumRivalCompareScreen extends ConsumerStatefulWidget {
  const PremiumRivalCompareScreen({super.key});

  @override
  ConsumerState<PremiumRivalCompareScreen> createState() =>
      _PremiumRivalCompareScreenState();
}

class _PremiumRivalCompareScreenState
    extends ConsumerState<PremiumRivalCompareScreen> {
  static const String _pinnedRivalKeyPrefix = 'premium_rival_pinned_';
  static const String _alertsEnabledKeyPrefix = 'premium_rival_alerts_enabled_';
  static const String _allGapKeyPrefix = 'premium_rival_gap_all_';
  static const String _weeklyGapKeyPrefix = 'premium_rival_gap_weekly_';
  static const String _monthlyGapKeyPrefix = 'premium_rival_gap_monthly_';

  final SubscriptionService _subscriptionService = SubscriptionService();
  bool _isChecking = true;
  bool _isPremium = false;
  RivalSortMode _sortMode = RivalSortMode.nearest;
  String? _pinnedRivalUserId;
  bool _alertsEnabled = true;
  List<String> _recentAlerts = const [];
  String? _lastAlertEvaluationSignature;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    await _loadPreferences();
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
      ref.invalidate(rivalCompareDataProvider);
    }
  }

  String _keyFor(String prefix) {
    final userId = ref.read(currentUserIdProvider) ?? 'anonymous';
    return '$prefix$userId';
  }

  String _gapKey(String prefix, String rivalUserId) {
    return '${_keyFor(prefix)}_$rivalUserId';
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _pinnedRivalUserId = prefs.getString(_keyFor(_pinnedRivalKeyPrefix));
      _alertsEnabled = prefs.getBool(_keyFor(_alertsEnabledKeyPrefix)) ?? true;
    });
  }

  Future<void> _togglePinnedRival(String rivalUserId) async {
    final prefs = await SharedPreferences.getInstance();
    final next = _pinnedRivalUserId == rivalUserId ? null : rivalUserId;
    if (next == null) {
      await prefs.remove(_keyFor(_pinnedRivalKeyPrefix));
    } else {
      await prefs.setString(_keyFor(_pinnedRivalKeyPrefix), next);
    }
    if (!mounted) return;
    setState(() {
      _pinnedRivalUserId = next;
      _lastAlertEvaluationSignature = null;
    });
  }

  Future<void> _setAlertsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFor(_alertsEnabledKeyPrefix), enabled);
    if (!mounted) return;
    setState(() => _alertsEnabled = enabled);
  }

  void _queueAlertEvaluation(RivalCompareData data) {
    if (!_alertsEnabled || _pinnedRivalUserId == null) return;

    final yourEntry = _yourEntry(data);
    final rival = data.entries
        .where((entry) => entry.userId == _pinnedRivalUserId)
        .cast<RivalCompareEntry?>()
        .firstWhere((_) => true, orElse: () => null);
    if (yourEntry == null || rival == null) return;

    final signature =
        '${yourEntry.allTimeScore}-${yourEntry.weeklyGain}-${yourEntry.monthlyGain}-${rival.allTimeScore}-${rival.weeklyGain}-${rival.monthlyGain}';
    if (_lastAlertEvaluationSignature == signature) return;
    _lastAlertEvaluationSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _evaluatePinnedRivalAlerts(yourEntry, rival);
    });
  }

  Future<void> _evaluatePinnedRivalAlerts(
    RivalCompareEntry you,
    RivalCompareEntry rival,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final allGapNow = rival.gapToYou;
    final weeklyGapNow = rival.weeklyGain - you.weeklyGain;
    final monthlyGapNow = rival.monthlyGain - you.monthlyGain;

    final allKey = _gapKey(_allGapKeyPrefix, rival.userId);
    final weeklyKey = _gapKey(_weeklyGapKeyPrefix, rival.userId);
    final monthlyKey = _gapKey(_monthlyGapKeyPrefix, rival.userId);

    final previousAll = prefs.getInt(allKey);
    final previousWeekly = prefs.getInt(weeklyKey);
    final previousMonthly = prefs.getInt(monthlyKey);

    final alerts = <String>[];
    final allAlert = _gapTransitionAlert(
      label: 'all-time',
      rivalName: rival.displayName,
      previousGap: previousAll,
      currentGap: allGapNow,
    );
    if (allAlert != null) alerts.add(allAlert);

    final weeklyAlert = _gapTransitionAlert(
      label: 'weekly',
      rivalName: rival.displayName,
      previousGap: previousWeekly,
      currentGap: weeklyGapNow,
    );
    if (weeklyAlert != null) alerts.add(weeklyAlert);

    final monthlyAlert = _gapTransitionAlert(
      label: 'monthly',
      rivalName: rival.displayName,
      previousGap: previousMonthly,
      currentGap: monthlyGapNow,
    );
    if (monthlyAlert != null) alerts.add(monthlyAlert);

    await prefs.setInt(allKey, allGapNow);
    await prefs.setInt(weeklyKey, weeklyGapNow);
    await prefs.setInt(monthlyKey, monthlyGapNow);

    if (!mounted || alerts.isEmpty) return;
    setState(() {
      _recentAlerts = [...alerts, ..._recentAlerts].take(4).toList();
    });
  }

  String? _gapTransitionAlert({
    required String label,
    required String rivalName,
    required int? previousGap,
    required int currentGap,
  }) {
    if (previousGap == null) return null;
    if (previousGap > 0 && currentGap <= 0) {
      return 'You passed $rivalName on $label.';
    }
    if (previousGap <= 0 && currentGap > 0) {
      return '$rivalName moved ahead of you on $label.';
    }
    return null;
  }

  void _showPremiumRequiredDialog() {
    showDialog<void>(
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
          'Rival Compare is available to Premium users.',
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

    final dataAsync = ref.watch(rivalCompareDataProvider);
    final paceAsync = ref.watch(goalsPaceDataProvider(GoalsMetric.statusxp));

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
            const Text('Rival Compare'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              right: -90,
              child: _ambientGlow(
                size: 260,
                color: accentSecondary.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              bottom: -140,
              left: -80,
              child: _ambientGlow(
                size: 280,
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
                    'Failed to load rival comparison\n$error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: textSecondary),
                  ),
                ),
              ),
              data: (data) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(rivalCompareDataProvider);
                  ref.invalidate(goalsPaceDataProvider(GoalsMetric.statusxp));
                  await ref.read(rivalCompareDataProvider.future);
                  await ref.read(
                    goalsPaceDataProvider(GoalsMetric.statusxp).future,
                  );
                },
                child: Builder(
                  builder: (context) {
                    _queueAlertEvaluation(data);
                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildOverviewCard(data),
                        const SizedBox(height: 12),
                        _buildSortSelector(),
                        const SizedBox(height: 12),
                        _buildPassTargetsCard(data, paceAsync.valueOrNull),
                        const SizedBox(height: 12),
                        _buildTrackedRivalCard(data, paceAsync.valueOrNull),
                        const SizedBox(height: 12),
                        _buildAlertsCard(),
                        const SizedBox(height: 14),
                        _sectionHeader('Top Rivals', icon: Icons.bolt_rounded),
                        const SizedBox(height: 10),
                        ..._sortedEntries(data)
                            .where((entry) => !entry.isYou)
                            .take(15)
                            .map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildRivalCard(
                                  entry,
                                  yourEntry: _yourEntry(data),
                                  paceData: paceAsync.valueOrNull,
                                ),
                              ),
                            ),
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

  Widget _buildTrackedRivalCard(
    RivalCompareData data,
    GoalsPaceData? paceData,
  ) {
    final yourEntry = _yourEntry(data);
    final tracked = _pinnedRivalUserId == null
        ? null
        : data.entries
              .where((entry) => entry.userId == _pinnedRivalUserId)
              .cast<RivalCompareEntry?>()
              .firstWhere((_) => true, orElse: () => null);

    if (yourEntry == null) return const SizedBox.shrink();

    if (tracked == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: _panelDecoration(
          accent: accentSecondary,
          glow: false,
          subtle: true,
        ),
        child: const Text(
          'Pin a rival from the list below to track a direct chase line.',
          style: TextStyle(color: textSecondary),
        ),
      );
    }

    final allNeed = (tracked.gapToYou + 1).clamp(0, 1 << 30);
    final weeklyNeed = (tracked.weeklyGain - yourEntry.weeklyGain + 1).clamp(
      0,
      1 << 30,
    );
    final monthlyNeed = (tracked.monthlyGain - yourEntry.monthlyGain + 1).clamp(
      0,
      1 << 30,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(accent: accentPrimary, glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader('Tracked Rival', icon: Icons.radar_rounded),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => _togglePinnedRival(tracked.userId),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: accentPrimary.withValues(alpha: 0.12),
                    border: Border.all(
                      color: accentPrimary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.push_pin, color: accentPrimary, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'PINNED',
                        style: TextStyle(
                          color: accentPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Text(
            tracked.displayName,
            style: const TextStyle(
              color: accentPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('All-time need', _format(allNeed)),
              _chip('Weekly need', _format(weeklyNeed)),
              _chip('Monthly need', _format(monthlyNeed)),
              if (paceData != null && weeklyNeed > 0)
                _chip(
                  'Weekly pace',
                  paceData.weekly.remainingDays <= 0
                      ? _format(weeklyNeed)
                      : '${_format((weeklyNeed / paceData.weekly.remainingDays).ceil())}/day',
                ),
              if (paceData != null && monthlyNeed > 0)
                _chip(
                  'Monthly pace',
                  paceData.monthly.remainingDays <= 0
                      ? _format(monthlyNeed)
                      : '${_format((monthlyNeed / paceData.monthly.remainingDays).ceil())}/day',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(
        accent: _alertsEnabled ? accentSuccess : accentWarning,
        glow: _alertsEnabled,
        subtle: !_alertsEnabled,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _sectionHeader('Rival Alerts', icon: Icons.notifications_active),
              const Spacer(),
              Row(
                children: [
                  const Text(
                    'Alerts',
                    style: TextStyle(color: textMuted, fontSize: 12),
                  ),
                  const SizedBox(width: 6),
                  Transform.scale(
                    scale: 0.88,
                    child: Switch(
                      value: _alertsEnabled,
                      onChanged: _setAlertsEnabled,
                      activeThumbColor: accentPrimary,
                      activeTrackColor: accentPrimary.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_recentAlerts.isEmpty)
            const Text(
              'No recent pass/get-passed alerts yet.',
              style: TextStyle(color: textSecondary),
            )
          else
            ..._recentAlerts.map(
              (alert) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '• $alert',
                  style: const TextStyle(color: textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard(RivalCompareData data) {
    final yourEntry = _yourEntry(data);
    final yourRank = yourEntry?.allTimeRank;
    final above = data.entries.where((entry) => entry.gapToYou > 0).length;
    final below = data.entries.where((entry) => entry.gapToYou < 0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(accent: accentPrimary, glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Position',
            style: TextStyle(color: textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'All-Time ${yourRank != null ? '#$yourRank' : 'Unranked'}',
            style: const TextStyle(
              color: textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_format(data.yourAllTimeScore)} StatusXP',
            style: const TextStyle(
              color: accentPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _overviewChip('Ahead of you', '$above'),
              _overviewChip('Behind you', '$below'),
              _overviewChip('Weekly gain', _format(yourEntry?.weeklyGain ?? 0)),
              _overviewChip(
                'Monthly gain',
                _format(yourEntry?.monthlyGain ?? 0),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSortSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: _panelDecoration(accent: accentSecondary, subtle: true),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: RivalSortMode.values.map((mode) {
            final selected = _sortMode == mode;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: selected,
                showCheckmark: false,
                label: Text(_sortLabel(mode).toUpperCase()),
                selectedColor: accentPrimary.withValues(alpha: 0.24),
                backgroundColor: Colors.black.withValues(alpha: 0.22),
                side: BorderSide(
                  color: selected
                      ? accentPrimary.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.1),
                ),
                labelStyle: TextStyle(
                  color: selected ? accentPrimary : textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                onSelected: (_) => setState(() => _sortMode = mode),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPassTargetsCard(RivalCompareData data, GoalsPaceData? paceData) {
    final yourEntry = _yourEntry(data);
    if (yourEntry == null) {
      return const SizedBox.shrink();
    }
    final nearestAhead = _nearestAhead(data);
    final weeklyTarget = _nextWeeklyTarget(data, yourEntry);
    final monthlyTarget = _nextMonthlyTarget(data, yourEntry);
    final weeklyRemainingDays = paceData?.weekly.remainingDays ?? 0;
    final monthlyRemainingDays = paceData?.monthly.remainingDays ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(accent: accentSecondary, glow: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('Pass Targets', icon: Icons.track_changes_rounded),
          const SizedBox(height: 8),
          _targetRow(
            title: 'All-time next pass',
            rivalName: nearestAhead?.displayName,
            needed: nearestAhead == null ? 0 : nearestAhead.gapToYou + 1,
            context: nearestAhead == null
                ? 'You are currently first overall.'
                : 'Need ${_format(nearestAhead.gapToYou + 1)} StatusXP to pass.',
          ),
          const SizedBox(height: 8),
          _targetRow(
            title: 'Weekly next pass',
            rivalName: weeklyTarget?.displayName,
            needed: weeklyTarget == null
                ? 0
                : (weeklyTarget.weeklyGain - yourEntry.weeklyGain + 1),
            context: weeklyTarget == null
                ? 'You are first for this week.'
                : _paceContext(
                    needed:
                        (weeklyTarget.weeklyGain - yourEntry.weeklyGain + 1),
                    daysRemaining: weeklyRemainingDays,
                  ),
          ),
          const SizedBox(height: 8),
          _targetRow(
            title: 'Monthly next pass',
            rivalName: monthlyTarget?.displayName,
            needed: monthlyTarget == null
                ? 0
                : (monthlyTarget.monthlyGain - yourEntry.monthlyGain + 1),
            context: monthlyTarget == null
                ? 'You are first for this month.'
                : _paceContext(
                    needed:
                        (monthlyTarget.monthlyGain - yourEntry.monthlyGain + 1),
                    daysRemaining: monthlyRemainingDays,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _targetRow({
    required String title,
    required String? rivalName,
    required int needed,
    required String context,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentPrimary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: textMuted,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            rivalName == null
                ? 'No target'
                : '$rivalName • +${_format(needed)} needed',
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            context,
            style: const TextStyle(color: textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRivalCard(
    RivalCompareEntry entry, {
    required RivalCompareEntry? yourEntry,
    required GoalsPaceData? paceData,
  }) {
    final gap = entry.gapToYou;
    final gapText = gap == 0
        ? 'You'
        : gap > 0
        ? '+${_format(gap)} ahead'
        : '${_format(gap.abs())} behind';
    final neededToPass = gap > 0 ? gap + 1 : 0;
    final weeklyNeeded = yourEntry == null
        ? 0
        : (entry.weeklyGain - yourEntry.weeklyGain + 1).clamp(0, 1 << 30);
    final monthlyNeeded = yourEntry == null
        ? 0
        : (entry.monthlyGain - yourEntry.monthlyGain + 1).clamp(0, 1 << 30);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(
        accent: entry.isYou
            ? accentPrimary
            : (_pinnedRivalUserId == entry.userId
                  ? accentSecondary
                  : accentPrimary),
        glow: entry.isYou || _pinnedRivalUserId == entry.userId,
        subtle: !entry.isYou && _pinnedRivalUserId != entry.userId,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            backgroundImage:
                entry.avatarUrl != null && entry.avatarUrl!.isNotEmpty
                ? NetworkImage(entry.avatarUrl!)
                : null,
            child: entry.avatarUrl == null || entry.avatarUrl!.isEmpty
                ? const Icon(Icons.person, size: 18, color: textMuted)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '#${entry.allTimeRank}',
                      style: TextStyle(
                        color: entry.isYou ? accentSuccess : accentPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.displayName,
                        style: TextStyle(
                          color: entry.isYou ? accentPrimary : textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: _pinnedRivalUserId == entry.userId
                          ? 'Unpin rival'
                          : 'Pin rival',
                      onPressed: () => _togglePinnedRival(entry.userId),
                      icon: Icon(
                        _pinnedRivalUserId == entry.userId
                            ? Icons.push_pin
                            : Icons.push_pin_outlined,
                        color: _pinnedRivalUserId == entry.userId
                            ? accentSecondary
                            : textMuted,
                        size: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_format(entry.allTimeScore)} StatusXP • $gapText',
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    _chip('Weekly', _format(entry.weeklyGain)),
                    _chip('Monthly', _format(entry.monthlyGain)),
                    if (neededToPass > 0)
                      _chip('To pass', _format(neededToPass)),
                    if (weeklyNeeded > 0)
                      _chip(
                        'Weekly push',
                        paceData == null || paceData.weekly.remainingDays == 0
                            ? _format(weeklyNeeded)
                            : '${_format((weeklyNeeded / paceData.weekly.remainingDays).ceil())}/d',
                      ),
                    if (monthlyNeeded > 0)
                      _chip(
                        'Monthly push',
                        paceData == null || paceData.monthly.remainingDays == 0
                            ? _format(monthlyNeeded)
                            : '${_format((monthlyNeeded / paceData.monthly.remainingDays).ceil())}/d',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, {IconData? icon}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: accentPrimary.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
        ],
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
            letterSpacing: 1.0,
          ),
        ),
      ],
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

  BoxDecoration _panelDecoration({
    required Color accent,
    bool glow = false,
    bool subtle = false,
  }) {
    final base = subtle
        ? Colors.black.withValues(alpha: 0.15)
        : surfaceLight.withValues(alpha: 0.92);
    final gradientOpacity = subtle ? 0.07 : 0.15;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: LinearGradient(
        colors: [
          accent.withValues(alpha: gradientOpacity),
          base,
          base,
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(color: accent.withValues(alpha: subtle ? 0.2 : 0.34)),
      boxShadow: glow
          ? [
              BoxShadow(
                color: accent.withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ]
          : null,
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentPrimary.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _format(int value) {
    final raw = value.toString();
    final chars = raw.split('');
    final buffer = StringBuffer();
    for (int index = 0; index < chars.length; index++) {
      final reverseIndex = chars.length - index;
      buffer.write(chars[index]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  Widget _overviewChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentPrimary.withValues(alpha: 0.18)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  RivalCompareEntry? _yourEntry(RivalCompareData data) {
    for (final entry in data.entries) {
      if (entry.isYou) return entry;
    }
    return null;
  }

  RivalCompareEntry? _nearestAhead(RivalCompareData data) {
    RivalCompareEntry? target;
    for (final entry in data.entries) {
      if (entry.gapToYou <= 0) continue;
      if (target == null || entry.gapToYou < target.gapToYou) {
        target = entry;
      }
    }
    return target;
  }

  RivalCompareEntry? _nextWeeklyTarget(
    RivalCompareData data,
    RivalCompareEntry yourEntry,
  ) {
    RivalCompareEntry? target;
    for (final entry in data.entries) {
      if (entry.isYou) continue;
      if (entry.weeklyGain <= yourEntry.weeklyGain) continue;
      if (target == null || entry.weeklyGain < target.weeklyGain) {
        target = entry;
      }
    }
    return target;
  }

  RivalCompareEntry? _nextMonthlyTarget(
    RivalCompareData data,
    RivalCompareEntry yourEntry,
  ) {
    RivalCompareEntry? target;
    for (final entry in data.entries) {
      if (entry.isYou) continue;
      if (entry.monthlyGain <= yourEntry.monthlyGain) continue;
      if (target == null || entry.monthlyGain < target.monthlyGain) {
        target = entry;
      }
    }
    return target;
  }

  List<RivalCompareEntry> _sortedEntries(RivalCompareData data) {
    final entries = [...data.entries];
    switch (_sortMode) {
      case RivalSortMode.nearest:
        entries.sort((a, b) {
          final aDistance = a.gapToYou.abs();
          final bDistance = b.gapToYou.abs();
          final distance = aDistance.compareTo(bDistance);
          if (distance != 0) return distance;
          return a.allTimeRank.compareTo(b.allTimeRank);
        });
        return entries;
      case RivalSortMode.allTime:
        entries.sort((a, b) => a.allTimeRank.compareTo(b.allTimeRank));
        return entries;
      case RivalSortMode.weekly:
        entries.sort((a, b) => b.weeklyGain.compareTo(a.weeklyGain));
        return entries;
      case RivalSortMode.monthly:
        entries.sort((a, b) => b.monthlyGain.compareTo(a.monthlyGain));
        return entries;
    }
  }

  String _paceContext({required int needed, required int daysRemaining}) {
    if (daysRemaining <= 0) {
      return 'Need ${_format(needed)} before this window closes.';
    }
    final perDay = (needed / daysRemaining).ceil();
    return '${_format(daysRemaining)} day(s) left • about ${_format(perDay)}/day to pass.';
  }

  String _sortLabel(RivalSortMode mode) {
    switch (mode) {
      case RivalSortMode.nearest:
        return 'Nearest';
      case RivalSortMode.allTime:
        return 'All-Time';
      case RivalSortMode.weekly:
        return 'Weekly';
      case RivalSortMode.monthly:
        return 'Monthly';
    }
  }
}

enum RivalSortMode { nearest, allTime, weekly, monthly }
