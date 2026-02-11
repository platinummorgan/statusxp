import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/domain/premium_features_data.dart';
import 'package:statusxp/services/subscription_service.dart';
import 'package:statusxp/state/premium_features_providers.dart';
import 'package:statusxp/theme/colors.dart';

class PremiumGoalsPaceScreen extends ConsumerStatefulWidget {
  const PremiumGoalsPaceScreen({super.key});

  @override
  ConsumerState<PremiumGoalsPaceScreen> createState() =>
      _PremiumGoalsPaceScreenState();
}

class _PremiumGoalsPaceScreenState
    extends ConsumerState<PremiumGoalsPaceScreen> {
  static const String _weeklyGoalKeyPrefix = 'premium_goal_weekly_';
  static const String _monthlyGoalKeyPrefix = 'premium_goal_monthly_';
  static const String _rangeGoalKeyPrefix = 'premium_goal_range_';

  final SubscriptionService _subscriptionService = SubscriptionService();
  final DateFormat _dateShort = DateFormat('MMM d');
  final DateFormat _dateLong = DateFormat('MMM d, y');
  bool _isChecking = true;
  bool _isPremium = false;
  GoalsMetric _selectedMetric = GoalsMetric.statusxp;
  int _weeklyGoal = 800;
  int _monthlyGoal = 3000;
  int _rangeGoal = 500;
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().toUtc().subtract(const Duration(days: 6)),
    end: DateTime.now().toUtc(),
  );

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadGoals();
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
      ref.invalidate(goalsPaceDataProvider(_selectedMetric));
    }
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    final weeklyDefault = _selectedMetric == GoalsMetric.statusxp ? 800 : 200;
    final monthlyDefault = _selectedMetric == GoalsMetric.statusxp ? 3000 : 800;
    final rangeDefault = _selectedMetric == GoalsMetric.statusxp ? 1200 : 300;
    if (!mounted) return;
    setState(() {
      _weeklyGoal =
          prefs.getInt(_goalKey(weekly: true, metric: _selectedMetric)) ??
          weeklyDefault;
      _monthlyGoal =
          prefs.getInt(_goalKey(weekly: false, metric: _selectedMetric)) ??
          monthlyDefault;
      _rangeGoal =
          prefs.getInt(_rangeGoalKey(metric: _selectedMetric)) ?? rangeDefault;
    });
  }

  Future<void> _saveGoal({required bool weekly, required int goal}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _goalKey(weekly: weekly, metric: _selectedMetric);
    if (weekly) {
      await prefs.setInt(key, goal);
      if (!mounted) return;
      setState(() => _weeklyGoal = goal);
    } else {
      await prefs.setInt(key, goal);
      if (!mounted) return;
      setState(() => _monthlyGoal = goal);
    }
  }

  Future<void> _saveRangeGoal(int goal) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_rangeGoalKey(metric: _selectedMetric), goal);
    if (!mounted) return;
    setState(() => _rangeGoal = goal);
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
          'Goals & Pace Coach is available to Premium users.',
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

  Future<void> _editGoal({
    required bool weekly,
    required int currentValue,
  }) async {
    final controller = TextEditingController(text: currentValue.toString());
    final title = weekly ? 'Set Weekly Goal' : 'Set Monthly Goal';
    final metricLabel = _metricUnitLabel(_selectedMetric);
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceLight,
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '$metricLabel goal'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) return;
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await _saveGoal(weekly: weekly, goal: result);
    }
  }

  Future<void> _editRangeGoal() async {
    final controller = TextEditingController(text: _rangeGoal.toString());
    final metricLabel = _metricUnitLabel(_selectedMetric);
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceLight,
        title: const Text('Set Range Goal'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '$metricLabel goal'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) return;
              Navigator.of(context).pop(parsed);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result > 0) {
      await _saveRangeGoal(result);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      currentDate: now,
      initialDateRange: DateTimeRange(
        start: _selectedRange.start.toLocal(),
        end: _selectedRange.end.toLocal(),
      ),
    );
    if (picked == null) return;
    if (!mounted) return;
    setState(() {
      _selectedRange = DateTimeRange(
        start: DateTime.utc(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        end: DateTime.utc(picked.end.year, picked.end.month, picked.end.day),
      );
    });
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

    final dataAsync = ref.watch(goalsPaceDataProvider(_selectedMetric));
    final rangeQuery = GoalsRangeQuery(
      metric: _selectedMetric,
      start: _selectedRange.start,
      end: _selectedRange.end,
    );
    final rangeAsync = ref.watch(goalsRangeDataProvider(rangeQuery));
    final customSnapshot = rangeAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: backgroundDark,
      appBar: AppBar(
        backgroundColor: surfaceLight,
        title: const Text('Goals & Pace Coach'),
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
              'Failed to load goals data\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: textSecondary),
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(goalsPaceDataProvider(_selectedMetric));
            ref.invalidate(goalsRangeDataProvider(rangeQuery));
            await ref.read(goalsPaceDataProvider(_selectedMetric).future);
            await ref.read(goalsRangeDataProvider(rangeQuery).future);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildMetricSelector(),
              const SizedBox(height: 12),
              _buildHeaderCard(data.currentValue),
              const SizedBox(height: 16),
              _buildRangePickerCard(),
              const SizedBox(height: 14),
              rangeAsync.when(
                loading: () => _buildRangeLoadingCard(),
                error: (_, __) => _buildRangeErrorCard(),
                data: (snapshot) => _buildPaceCard(
                  snapshot: PaceWindowInsight(
                    periodLabel: 'Custom Range',
                    periodStart: snapshot.periodStart,
                    periodEnd: snapshot.periodEnd,
                    currentGain: snapshot.currentGain,
                    projectedGain: snapshot.projectedGain,
                    rank: snapshot.rank,
                    totalPlayers: snapshot.totalPlayers,
                    gapToFirst: snapshot.gapToFirst,
                  ),
                  goal: _rangeGoal,
                  onEditGoal: _editRangeGoal,
                ),
              ),
              const SizedBox(height: 16),
              _buildPaceCard(
                snapshot: data.weekly,
                goal: _weeklyGoal,
                onEditGoal: () =>
                    _editGoal(weekly: true, currentValue: _weeklyGoal),
              ),
              const SizedBox(height: 14),
              _buildPaceCard(
                snapshot: data.monthly,
                goal: _monthlyGoal,
                onEditGoal: () =>
                    _editGoal(weekly: false, currentValue: _monthlyGoal),
              ),
              const SizedBox(height: 24),
              _buildCoachTips(data, customSnapshot: customSnapshot),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: GoalsMetric.values.map((metric) {
          final selected = metric == _selectedMetric;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              label: Text(_metricChipLabel(metric)),
              showCheckmark: false,
              selectedColor: accentPrimary.withValues(alpha: 0.2),
              backgroundColor: surfaceLight,
              side: BorderSide(
                color: selected
                    ? accentPrimary.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              labelStyle: TextStyle(
                color: selected ? accentPrimary : textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              onSelected: (_) async {
                if (metric == _selectedMetric) return;
                setState(() => _selectedMetric = metric);
                await _loadGoals();
                if (!mounted) return;
                ref.invalidate(goalsPaceDataProvider(metric));
                ref.invalidate(
                  goalsRangeDataProvider(
                    GoalsRangeQuery(
                      metric: metric,
                      start: _selectedRange.start,
                      end: _selectedRange.end,
                    ),
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRangePickerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentSecondary.withValues(alpha: 0.12),
            surfaceLight,
            surfaceLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentSecondary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: accentSecondary.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: accentSecondary.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              const Text(
                'Custom Date Range',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${_dateShort.format(_selectedRange.start.toLocal())} - ${_dateLong.format(_selectedRange.end.toLocal())}',
            style: const TextStyle(color: textSecondary),
            softWrap: true,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Icons.date_range, size: 16),
              label: const Text('Change'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: accentPrimary),
      ),
    );
  }

  Widget _buildRangeErrorCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Text(
        'Unable to load range data right now.',
        style: TextStyle(color: textSecondary),
      ),
    );
  }

  Widget _buildHeaderCard(int currentValue) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            accentPrimary.withValues(alpha: 0.2),
            accentSecondary.withValues(alpha: 0.15),
          ],
        ),
        border: Border.all(color: accentPrimary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current ${_metricTitle(_selectedMetric)}',
            style: const TextStyle(color: textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            _format(currentValue),
            style: const TextStyle(
              color: textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaceCard({
    required PaceWindowInsight snapshot,
    required int goal,
    required VoidCallback onEditGoal,
  }) {
    final pct = (snapshot.currentGain / goal).clamp(0, 1).toDouble();
    final remainingToGoal = (goal - snapshot.currentGain).clamp(0, 1 << 30);
    final neededDaily = snapshot.remainingDays > 0
        ? (remainingToGoal / snapshot.remainingDays).ceil()
        : remainingToGoal;
    final projectedDelta = snapshot.projectedGain - goal;
    final paceColor = projectedDelta >= 0 ? accentSuccess : accentWarning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            paceColor.withValues(alpha: 0.08),
            surfaceLight,
            surfaceLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: paceColor.withValues(alpha: 0.32)),
        boxShadow: [
          BoxShadow(
            color: paceColor.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  snapshot.periodLabel,
                  style: const TextStyle(
                    color: accentPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEditGoal,
                icon: const Icon(Icons.edit, size: 16),
                label: const Text('Set Goal'),
              ),
            ],
          ),
          Text(
            _periodScopeLabel(snapshot),
            style: const TextStyle(color: textMuted, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            '${_format(snapshot.currentGain)} / ${_format(goal)}',
            style: const TextStyle(
              color: textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation(accentPrimary),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _miniStat('Rank', snapshot.rank > 0 ? '#${snapshot.rank}' : '-'),
              _miniStat('Players', '${snapshot.totalPlayers}'),
              _miniStat('Projected', _format(snapshot.projectedGain)),
              _miniStat('Gap #1', _format(snapshot.gapToFirst)),
              _miniStat('Need/day', _format(neededDaily)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            projectedDelta >= 0
                ? 'On pace: projected +${_format(projectedDelta)} above goal'
                : 'Behind pace: projected ${_format(projectedDelta.abs())} short',
            style: TextStyle(color: paceColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachTips(
    GoalsPaceData data, {
    PaceWindowInsight? customSnapshot,
  }) {
    final weeklyRemaining = (_weeklyGoal - data.weekly.currentGain).clamp(
      0,
      1 << 30,
    );
    final monthlyRemaining = (_monthlyGoal - data.monthly.currentGain).clamp(
      0,
      1 << 30,
    );
    final weeklyNeed = data.weekly.remainingDays > 0
        ? (weeklyRemaining / data.weekly.remainingDays).ceil()
        : weeklyRemaining;
    final monthlyNeed = data.monthly.remainingDays > 0
        ? (monthlyRemaining / data.monthly.remainingDays).ceil()
        : monthlyRemaining;
    final customNeed = customSnapshot == null
        ? null
        : (() {
            final remaining = (_rangeGoal - customSnapshot.currentGain).clamp(
              0,
              1 << 30,
            );
            if (customSnapshot.remainingDays <= 0) return remaining;
            return (remaining / customSnapshot.remainingDays).ceil();
          })();

    final metricLabel = _metricUnitLabel(_selectedMetric);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentPrimary.withValues(alpha: 0.12),
            accentSecondary.withValues(alpha: 0.08),
            surfaceLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentPrimary.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accentPrimary.withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 16,
                color: accentPrimary.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
              const Text(
                'Coach Notes',
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _coachTipRow(
            title: 'Weekly window',
            subtitle:
                '${_periodScopeLabel(data.weekly)} • need ${_format(weeklyNeed)} $metricLabel/day',
            onTrack: data.weekly.projectedGain >= _weeklyGoal,
          ),
          const SizedBox(height: 4),
          _coachTipRow(
            title: 'Monthly window',
            subtitle:
                '${_periodScopeLabel(data.monthly)} • need ${_format(monthlyNeed)} $metricLabel/day',
            onTrack: data.monthly.projectedGain >= _monthlyGoal,
          ),
          if (customSnapshot != null && customNeed != null) ...[
            const SizedBox(height: 4),
            _coachTipRow(
              title: 'Custom range',
              subtitle:
                  '${_periodScopeLabel(customSnapshot)} • need ${_format(customNeed)} $metricLabel/day',
              onTrack: customSnapshot.projectedGain >= _rangeGoal,
            ),
          ] else ...[
            const SizedBox(height: 4),
            const Text(
              'Custom range pace appears after date-range data loads.',
              style: TextStyle(color: textMuted, fontSize: 12),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Tip: switch metric tabs above to coach StatusXP, Platinums, Xbox score, and Steam separately.',
            style: TextStyle(
              color: accentSecondary.withValues(alpha: 0.9),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _coachTipRow({
    required String title,
    required String subtitle,
    required bool onTrack,
  }) {
    final color = onTrack ? accentSuccess : accentWarning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            onTrack ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(color: textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            onTrack ? 'ON TRACK' : 'BEHIND',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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

  String _goalKey({required bool weekly, required GoalsMetric metric}) {
    final prefix = weekly ? _weeklyGoalKeyPrefix : _monthlyGoalKeyPrefix;
    return '$prefix${metric.name}';
  }

  String _rangeGoalKey({required GoalsMetric metric}) {
    return '$_rangeGoalKeyPrefix${metric.name}';
  }

  String _periodScopeLabel(PaceWindowInsight snapshot) {
    DateTime calendarDay(DateTime value) =>
        DateTime(value.year, value.month, value.day);
    final startUtc = snapshot.periodStart.toUtc();
    final endUtc = snapshot.periodEnd.toUtc();

    if (snapshot.periodLabel == 'Monthly') {
      // Monthly windows are stored with UTC boundaries (YYYY-MM-01 00:00 UTC).
      // Formatting the local time can roll back into the previous month for
      // western time zones (e.g., EST), so label by UTC month.
      return 'Applies to ${DateFormat('MMMM y').format(calendarDay(startUtc))}';
    }

    if (snapshot.periodLabel == 'Weekly') {
      return '${_dateShort.format(calendarDay(startUtc))} - ${_dateLong.format(calendarDay(endUtc))}';
    }

    final endInclusive = endUtc.subtract(const Duration(days: 1));
    return '${_dateShort.format(calendarDay(startUtc))} - ${_dateLong.format(calendarDay(endInclusive))}';
  }

  String _metricTitle(GoalsMetric metric) {
    switch (metric) {
      case GoalsMetric.statusxp:
        return 'StatusXP';
      case GoalsMetric.platinums:
        return 'Platinums';
      case GoalsMetric.xboxGamerscore:
        return 'Xbox Gamerscore';
      case GoalsMetric.steamAchievements:
        return 'Steam Achievements';
    }
  }

  String _metricUnitLabel(GoalsMetric metric) {
    switch (metric) {
      case GoalsMetric.statusxp:
        return 'StatusXP';
      case GoalsMetric.platinums:
        return 'platinums';
      case GoalsMetric.xboxGamerscore:
        return 'gamerscore';
      case GoalsMetric.steamAchievements:
        return 'achievements';
    }
  }

  String _metricChipLabel(GoalsMetric metric) {
    switch (metric) {
      case GoalsMetric.statusxp:
        return 'StatusXP';
      case GoalsMetric.platinums:
        return 'Platinums';
      case GoalsMetric.xboxGamerscore:
        return 'Xbox';
      case GoalsMetric.steamAchievements:
        return 'Steam';
    }
  }
}
