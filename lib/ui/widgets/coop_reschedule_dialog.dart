import 'package:flutter/material.dart';
import 'package:statusxp/domain/trophy_help_request.dart';
import 'package:statusxp/ui/widgets/coop_session_summary.dart';

class CoopRescheduleDialog extends StatefulWidget {
  const CoopRescheduleDialog({
    super.key,
    required this.request,
    required this.onSave,
  });
  final TrophyHelpRequest request;
  final Future<void> Function(DateTime? start) onSave;

  @override
  State<CoopRescheduleDialog> createState() => _CoopRescheduleDialogState();
}

class _CoopRescheduleDialogState extends State<CoopRescheduleDialog> {
  late DateTime? _start = widget.request.scheduledAt?.toLocal();
  bool _saving = false;
  String? _error;

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initial = _start != null && _start!.isAfter(now) ? _start! : now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    setState(() {
      _start = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_start != null && !_start!.isAfter(DateTime.now())) {
      setState(() => _error = 'Choose a future time or use flexible timing.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_start);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Could not save. Retry, or close and refresh if the plan has changed.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Change session time'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Accepted players stay on the team. Contact your partners to agree on the change; this does not send them a notification.',
            ),
            const SizedBox(height: 16),
            Text(
              _start == null
                  ? 'Session time to be agreed'
                  : coopLocalStart(_start!),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _saving ? null : _pickTime,
              icon: const Icon(Icons.event),
              label: const Text('Choose date and time'),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _start = null;
                      _error = null;
                    }),
              child: const Text('Use flexible timing'),
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save time'),
        ),
      ],
    ),
  );
}
