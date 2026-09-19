import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:statusxp/domain/trophy_help_request.dart';
import 'package:statusxp/ui/widgets/coop_session_summary.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class CoopConfirmedSession extends StatelessWidget {
  const CoopConfirmedSession({
    super.key,
    required this.request,
    required this.responses,
    required this.currentUserId,
  });
  final TrophyHelpRequest request;
  final List<TrophyHelpResponse> responses;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    final owner =
        currentUserId != null &&
        currentUserId == (request.profileId ?? request.userId);
    final confirmed = <String, TrophyHelpResponse>{};
    for (final response in responses) {
      if (['accepted', 'completed'].contains(response.status)) {
        confirmed.putIfAbsent(
          response.helperProfileId ?? response.helperUserId,
          () => response,
        );
      }
    }
    if (confirmed.isEmpty ||
        (!owner && !confirmed.containsKey(currentUserId))) {
      return const SizedBox.shrink();
    }
    final completed = request.status == 'completed';
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173A3A), Color(0xFF172A48)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CyberpunkTheme.neonCyan.withValues(alpha: .4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            completed
                ? 'Goal completed'
                : owner
                ? 'Your confirmed team'
                : 'You’re on the team',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            owner
                ? '${confirmed.length} of ${request.helpersNeeded} additional players ${completed ? 'completed' : 'confirmed'}'
                : completed
                ? 'This request is complete. Your help is recorded in My offers.'
                : 'Your offer was accepted. Contact the host to arrange the session.',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          CoopSessionSummary(request: request),
          if (!completed) ...[
            const SizedBox(height: 16),
            Text(
              request.scheduledAt == null
                  ? 'Next: agree on a start time with your partners.'
                  : 'Next: confirm everyone can make the scheduled time.',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use your platform to connect. Copy a username below to find your partner.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            if (owner)
              for (final response in confirmed.values)
                _contact(
                  context,
                  response.helperUsername ?? 'Confirmed player',
                  switch (request.platform) {
                    'psn' => response.helperPsnOnlineId,
                    'xbox' => response.helperXboxGamertag,
                    'steam' => response.helperSteamId,
                    _ => null,
                  },
                )
            else
              _contact(context, 'Host', request.platformUsername),
            if (owner) ...[
              const SizedBox(height: 12),
              const Text(
                'When the goal is done, use Mark Completed below to close the request for everyone.',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _contact(BuildContext context, String label, String? username) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (username == null || username.trim().isEmpty)
              const Text(
                'Platform username has not been shared yet.',
                style: TextStyle(color: Colors.white60),
              )
            else
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: username));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Platform username copied')),
                    );
                  }
                },
                icon: const Icon(Icons.copy, size: 16),
                label: Text(username, softWrap: true),
              ),
          ],
        ),
      );
}
