import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/domain/trophy_help_request.dart';

String coopUtcOffset(Duration offset) {
  final minutes = offset.inMinutes.abs();
  return 'UTC${offset.isNegative ? '-' : '+'}${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

String coopLocalStart(DateTime instant) {
  final local = instant.toLocal();
  return '${DateFormat('EEE, MMM d, y · h:mm a').format(local)} (${coopUtcOffset(local.timeZoneOffset)})';
}

class CoopSessionSummary extends StatelessWidget {
  const CoopSessionSummary({super.key, required this.request});
  final TrophyHelpRequest request;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (request.scheduleChangedAt != null) ...[
        Text(
          'Timing updated ${coopLocalStart(request.scheduleChangedAt!)}. Check the plan with your partners.',
          style: const TextStyle(color: Colors.amber),
        ),
        const SizedBox(height: 6),
      ],
      Text(
        'Group: host + ${request.helpersNeeded} ${request.helpersNeeded == 1 ? 'player' : 'players'}',
        style: const TextStyle(color: Colors.white70),
      ),
      const SizedBox(height: 6),
      Text(
        request.scheduledAt == null
            ? 'Session time to be agreed'
            : 'Your local time: ${coopLocalStart(request.scheduledAt!)}',
        style: const TextStyle(color: Colors.white70),
      ),
      if (request.scheduledAt != null &&
          request.sessionUtcOffsetMinutes != null) ...[
        const SizedBox(height: 4),
        Text(
          'Host scheduled in ${coopUtcOffset(Duration(minutes: request.sessionUtcOffsetMinutes!))}',
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
      ],
    ],
  );
}
