import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/trophy_help_request.dart';
import 'package:statusxp/services/trophy_help_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

final requestDetailsProvider = FutureProvider.autoDispose.family<TrophyHelpRequest?, String>(
  (ref, requestId) async {
    final service = ref.read(trophyHelpServiceProvider);
    return service.getRequest(requestId);
  },
);

final requestResponsesProvider = FutureProvider.autoDispose.family<List<TrophyHelpResponse>, String>(
  (ref, requestId) async {
    final service = ref.read(trophyHelpServiceProvider);
    return service.getRequestResponses(requestId);
  },
);

class TrophyHelpRequestDetailsScreen extends ConsumerWidget {
  final String requestId;

  const TrophyHelpRequestDetailsScreen({
    super.key,
    required this.requestId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final requestAsync = ref.watch(requestDetailsProvider(requestId));
    final responsesAsync = ref.watch(requestResponsesProvider(requestId));

    return Scaffold(
      backgroundColor: const Color(0xFF0f1729),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1f3a),
        title: const Text('Request Details'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(requestDetailsProvider(requestId));
          ref.invalidate(requestResponsesProvider(requestId));
        },
        child: requestAsync.when(
          data: (request) {
            if (request == null) {
              return const Center(
                child: Text('Request not found'),
              );
            }
            return _buildContent(context, theme, request, responsesAsync, ref);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonCyan),
            ),
          ),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.red.withOpacity(0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading request',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    TrophyHelpRequest request,
    AsyncValue<List<TrophyHelpResponse>> responsesAsync,
    WidgetRef ref,
  ) {
    // Platform-specific styling
    Color platformColor;
    IconData platformIcon;
    switch (request.platform.toLowerCase()) {
      case 'psn':
        platformColor = const Color(0xFF0070CC);
        platformIcon = Icons.sports_esports;
        break;
      case 'xbox':
        platformColor = const Color(0xFF107C10);
        platformIcon = Icons.videogame_asset;
        break;
      case 'steam':
        platformColor = const Color(0xFF1B2838);
        platformIcon = Icons.store;
        break;
      default:
        platformColor = Colors.grey;
        platformIcon = Icons.gamepad;
    }

    // Status styling
    Color statusColor;
    String statusText;
    switch (request.status) {
      case 'open':
        statusColor = CyberpunkTheme.neonCyan;
        statusText = 'Open';
        break;
      case 'assigned':
        statusColor = Colors.orange;
        statusText = 'Helper Assigned';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelled';
        break;
      case 'closed':
        statusColor = Colors.grey;
        statusText = 'Closed';
        break;
      default:
        statusColor = Colors.grey;
        statusText = request.status;
    }

    final currentUserId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    final isOwner = currentUserId == request.userId;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Request Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1f3a),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: CyberpunkTheme.neonCyan.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Platform and Status badges
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: platformColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: platformColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(platformIcon, size: 14, color: platformColor),
                        const SizedBox(width: 4),
                        Text(
                          request.platform.toUpperCase(),
                          style: TextStyle(
                            color: platformColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeago.format(request.createdAt),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Game title
              Text(
                request.gameTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // Achievement name
              Text(
                request.achievementName,
                style: TextStyle(
                  color: CyberpunkTheme.neonCyan.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),

              if (request.description != null && request.description!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Details',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  request.description!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],

              if (request.availability != null && request.availability!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule,
                      size: 16,
                      color: CyberpunkTheme.neonCyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Availability: ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        request.availability!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (request.platformUsername != null && request.platformUsername!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: CyberpunkTheme.neonCyan,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${request.platform.toUpperCase()} Username: ',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            request.platformUsername!,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: request.platformUsername!),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Username copied to clipboard')),
                              );
                            },
                            icon: const Icon(Icons.copy, size: 16),
                            color: CyberpunkTheme.neonCyan,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              // Owner actions
              if (isOwner && request.status == 'open') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Mark as Completed'),
                              content: const Text(
                                'Have you completed this achievement?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('No'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Yes'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              final service = TrophyHelpService(ref.read(supabaseClientProvider));
                              await service.updateRequestStatus(request.id, 'completed');
                              ref.invalidate(requestDetailsProvider(requestId));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Request marked as completed!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Mark Completed'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: const BorderSide(color: Colors.green),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Cancel Request'),
                              content: const Text(
                                'Are you sure you want to cancel this request?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('No'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Yes'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              final service = TrophyHelpService(ref.read(supabaseClientProvider));
                              await service.updateRequestStatus(request.id, 'cancelled');
                              ref.invalidate(requestDetailsProvider(requestId));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Request cancelled')),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Responses section
        Text(
          'OFFERS TO HELP',
          style: TextStyle(
            color: Colors.white.withOpacity(0.55),
            letterSpacing: 2.5,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 12),

        responsesAsync.when(
          data: (responses) {
            if (responses.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: const Color(0xFF1a1f3a),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: CyberpunkTheme.neonCyan.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No offers yet',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Wait for other players to offer help',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: responses.map((response) {
                return _buildResponseCard(context, request, response, isOwner, ref);
              }).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonCyan),
              ),
            ),
          ),
          error: (error, stack) => Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Error loading responses: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponseCard(
    BuildContext context,
    TrophyHelpRequest request,
    TrophyHelpResponse response,
    bool isOwner,
    WidgetRef ref,
  ) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (response.status) {
      case 'accepted':
        statusColor = Colors.green;
        statusText = 'Accepted';
        statusIcon = Icons.check_circle;
        break;
      case 'declined':
        statusColor = Colors.red;
        statusText = 'Declined';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = CyberpunkTheme.neonCyan;
        statusText = 'Pending';
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1f3a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: response.status == 'accepted'
              ? Colors.green.withOpacity(0.3)
              : CyberpunkTheme.neonCyan.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.person,
                size: 20,
                color: CyberpunkTheme.neonCyan,
              ),
              const SizedBox(width: 8),
              Text(
                'Helper ${response.helperUsername ?? response.helperUserId.substring(0, 8)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: statusColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (response.message != null && response.message!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              response.message!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            timeago.format(response.createdAt),
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 12,
            ),
          ),

          // Show helper's platform contact info if accepted
          if (response.status == 'accepted') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.contact_page,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Contact Info',
                        style: TextStyle(
                          color: Colors.green.shade300,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (request.platform.toLowerCase().contains('ps') && response.helperPsnOnlineId != null)
                    _buildContactRow(context, 'PSN ID', response.helperPsnOnlineId!)
                  else if (request.platform.toLowerCase().contains('xbox') && response.helperXboxGamertag != null)
                    _buildContactRow(context, 'Xbox Gamertag', response.helperXboxGamertag!)
                  else if (request.platform.toLowerCase().contains('steam') && response.helperSteamId != null)
                    _buildContactRow(context, 'Steam ID', response.helperSteamId!)
                  else
                    Text(
                      'No platform username available',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Owner actions for pending responses
          if (isOwner && response.status == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final service = TrophyHelpService(ref.read(supabaseClientProvider));
                        await service.acceptHelper(response.id);
                        // Update request status to assigned
                        await service.updateRequestStatus(request.id, 'assigned');
                        ref.invalidate(requestResponsesProvider(requestId));
                        ref.invalidate(requestDetailsProvider(requestId));
                        if (context.mounted) {
                          // Show helper's contact info
                          String contactInfo = 'Helper accepted!';
                          final platform = request.platform.toLowerCase();
                          if (platform.contains('ps') && response.helperPsnOnlineId != null) {
                            contactInfo += '\n\nPSN: ${response.helperPsnOnlineId}';
                          } else if (platform.contains('xbox') && response.helperXboxGamertag != null) {
                            contactInfo += '\n\nXbox: ${response.helperXboxGamertag}';
                          } else if (platform.contains('steam') && response.helperSteamId != null) {
                            contactInfo += '\n\nSteam ID: ${response.helperSteamId}';
                          }
                          
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Helper Accepted!'),
                              content: Text(contactInfo),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    if (platform.contains('ps') && response.helperPsnOnlineId != null) {
                                      Clipboard.setData(ClipboardData(text: response.helperPsnOnlineId!));
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('PSN ID copied to clipboard')),
                                      );
                                    } else if (platform.contains('xbox') && response.helperXboxGamertag != null) {
                                      Clipboard.setData(ClipboardData(text: response.helperXboxGamertag!));
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Gamertag copied to clipboard')),
                                      );
                                    } else if (platform.contains('steam') && response.helperSteamId != null) {
                                      Clipboard.setData(ClipboardData(text: response.helperSteamId!));
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Steam ID copied to clipboard')),
                                      );
                                    } else {
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: const Text('Copy & Close'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Accept'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.2),
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        final service = TrophyHelpService(ref.read(supabaseClientProvider));
                        await service.declineHelper(response.id);
                        ref.invalidate(requestResponsesProvider(requestId));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Helper declined')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$label copied to clipboard')),
            );
          },
          icon: const Icon(Icons.copy, size: 14),
          color: CyberpunkTheme.neonCyan,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
