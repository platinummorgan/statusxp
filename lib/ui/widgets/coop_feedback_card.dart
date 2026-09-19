import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/coop_feedback.dart';
import 'package:statusxp/state/statusxp_providers.dart';

class CoopFeedbackCard extends ConsumerStatefulWidget {
  const CoopFeedbackCard({super.key, required this.requestId});
  final String requestId;
  @override
  ConsumerState<CoopFeedbackCard> createState() => _CoopFeedbackCardState();
}

class _CoopFeedbackCardState extends ConsumerState<CoopFeedbackCard> {
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  bool _saved = false;
  String? _outcome;
  bool? _teamAgain;
  String? _saveError;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final feedback = await ref
          .read(trophyHelpServiceProvider)
          .getMyFeedback(widget.requestId);
      if (!mounted) return;
      setState(() {
        _outcome = feedback?.outcome;
        _teamAgain = feedback?.teamAgain;
        _saved = feedback != null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadFailed = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _save() async {
    if (_saving || _outcome == null) return;
    final feedback = CoopFeedback(outcome: _outcome!, teamAgain: _teamAgain);
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await ref
          .read(trophyHelpServiceProvider)
          .saveFeedback(widget.requestId, feedback);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your session feedback is saved')),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError =
              'Could not save feedback. Your choices are still here; please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF172638),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How did this session go for you?',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Your feedback is private and is not shown to other players.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        if (_loading)
          const LinearProgressIndicator()
        else if (_loadFailed) ...[
          const Text('Could not load your feedback.'),
          TextButton(onPressed: _load, child: const Text('Retry feedback')),
        ] else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in const {
                'goal_completed': 'Reached the goal',
                'made_progress': 'Made progress',
                'did_not_play': 'Did not get to play',
              }.entries)
                ChoiceChip(
                  label: Text(choice.value),
                  selected: _outcome == choice.key,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _outcome = choice.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Would you team up again?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final choice in <bool?, String>{
                true: 'Yes',
                false: 'No',
                null: 'Not sure',
              }.entries)
                ChoiceChip(
                  label: Text(choice.value),
                  selected: _teamAgain == choice.key,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() => _teamAgain = choice.key),
                ),
            ],
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 8),
            Text(
              _saveError!,
              style: const TextStyle(color: Colors.orangeAccent),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving || _outcome == null ? null : _save,
            child: Text(
              _saving
                  ? 'Saving…'
                  : _saved
                  ? 'Update feedback'
                  : 'Save feedback',
            ),
          ),
        ],
      ],
    ),
  );
}
