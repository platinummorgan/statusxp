import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/trophy_help_request.dart';
import 'package:statusxp/services/trophy_help_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/widgets/offer_help_dialog.dart';
import 'package:timeago/timeago.dart' as timeago;

final trophyHelpServiceProvider = Provider<TrophyHelpService>((ref) {
  return TrophyHelpService(ref.read(supabaseClientProvider));
});

// Provider for open requests filtered by platform
final openRequestsProvider = FutureProvider.autoDispose
    .family<List<TrophyHelpRequest>, String?>((ref, platform) async {
  final service = ref.read(trophyHelpServiceProvider);
  return service.getOpenRequests(platform: platform);
});

final myRequestsProvider = FutureProvider.autoDispose<List<TrophyHelpRequest>>((ref) async {
  final service = ref.read(trophyHelpServiceProvider);
  return service.getMyRequests();
});

class CoopPartnersScreen extends ConsumerStatefulWidget {
  const CoopPartnersScreen({super.key});

  @override
  ConsumerState<CoopPartnersScreen> createState() => _CoopPartnersScreenState();
}

class _CoopPartnersScreenState extends ConsumerState<CoopPartnersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedPlatform;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Co-op Partners'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Find Help', icon: Icon(Icons.search)),
            Tab(text: 'My Requests', icon: Icon(Icons.list)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _FindHelpTab(selectedPlatform: _selectedPlatform, onPlatformChanged: (value) {
            setState(() {
              _selectedPlatform = value;
            });
          }),
          const _MyRequestsTab(),
        ],
      ),
    );
  }
}

// Separate widget for Find Help tab to isolate provider watching
class _FindHelpTab extends ConsumerWidget {
  final String? selectedPlatform;
  final ValueChanged<String?> onPlatformChanged;

  const _FindHelpTab({
    required this.selectedPlatform,
    required this.onPlatformChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final requestsAsync = ref.watch(openRequestsProvider(selectedPlatform));

    return Column(
    return Column(
      children: [
        // Platform filter
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1f3a),
            border: Border(
              bottom: BorderSide(
                color: CyberpunkTheme.neonCyan.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              const Text(
                'Platform:',
                style: TextStyle(
                  color: CyberpunkTheme.neonCyan,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  children: [
                    _buildPlatformChip('All', null),
                    _buildPlatformChip('PSN', 'psn'),
                    _buildPlatformChip('Xbox', 'xbox'),
                    _buildPlatformChip('Steam', 'steam'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Requests list
        Expanded(
          child: requestsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: $error'),
                ],
              ),
            ),
            data: (requests) {
              if (requests.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_off,
                        size: 64,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No active requests',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to request help!',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(openRequestsProvider);
                },
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    return _RequestCard(request: requests[index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformChip(String label, String? value) {
    final isSelected = selectedPlatform == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        onPlatformChanged(selected ? value : null);
      },
      backgroundColor: const Color(0xFF1a1f3a),
      selectedColor: CyberpunkTheme.neonCyan.withOpacity(0.3),
      checkmarkColor: CyberpunkTheme.neonCyan,
      labelStyle: TextStyle(
        color: isSelected ? CyberpunkTheme.neonCyan : Colors.white70,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? CyberpunkTheme.neonCyan : Colors.white24,
      ),
    );
  }

}

// Separate stateless widget for request card
class _RequestCard extends ConsumerWidget {
  final TrophyHelpRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Color platformColor;
    IconData platformIcon;

    switch (request.platform.toLowerCase()) {
      case 'psn':
      case 'playstation':
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

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1a1f3a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: CyberpunkTheme.neonCyan.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: () {
          context.push('/coop-partners/${request.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with platform and time
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
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeago.format(request.createdAt),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Game title
              Text(
                request.gameTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Achievement name
              Row(
                children: [
                  Icon(
                    Icons.emoji_events,
                    size: 16,
                    color: CyberpunkTheme.neonCyan.withOpacity(0.7),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.achievementName,
                      style: TextStyle(
                        color: CyberpunkTheme.neonCyan.withOpacity(0.9),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              if (request.description != null) ...[
                const SizedBox(height: 12),
                Text(
                  request.description!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              if (request.availability != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 14,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      request.availability!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),

              // Action button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => OfferHelpDialog(request: request),
                    );
                    
                    if (result == true) {
                      // Refresh the list after offering help
                      ref.invalidate(openRequestsProvider);
                    }
                  },
                  icon: const Icon(Icons.handshake, size: 18),
                  label: const Text('Offer Help'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CyberpunkTheme.neonCyan.withOpacity(0.2),
                    foregroundColor: CyberpunkTheme.neonCyan,
                    side: const BorderSide(color: CyberpunkTheme.neonCyan),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

// Separate widget for My Requests tab to isolate provider watching  
class _MyRequestsTab extends ConsumerWidget {
  const _MyRequestsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final myRequestsAsync = ref.watch(myRequestsProvider);

    return myRequestsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonCyan),
        ),
      ),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
          ],
        ),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'No requests yet',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a request to find co-op partners',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myRequestsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              return _MyRequestCard(request: requests[index]);
            },
          ),
        );
      },
    );
  }
}

// Separate stateless widget for my request card
class _MyRequestCard extends ConsumerWidget {
  final TrophyHelpRequest request;

  const _MyRequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeAgo = timeago.format(request.createdAt);
    
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
      case 'matched':
        statusColor = Colors.orange;
        statusText = 'Matched';
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Completed';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelled';
        break;
      default:
        statusColor = Colors.grey;
        statusText = request.status;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1a1f3a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: CyberpunkTheme.neonCyan.withOpacity(0.2),
        ),
      ),
      child: InkWell(
        onTap: () {
          context.push('/coop-partners/${request.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with platform, status, and time
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
                    timeAgo,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Game title
              Text(
                request.gameTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              // Achievement name
              Text(
                request.achievementName,
                style: TextStyle(
                  color: CyberpunkTheme.neonCyan.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),

              if (request.description != null && request.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  request.description!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.push('/coop-partners/${request.id}');
                      },
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CyberpunkTheme.neonCyan,
                        side: const BorderSide(color: CyberpunkTheme.neonCyan),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (request.status == 'open') ...[
                    IconButton(
                      onPressed: () async {
                        // Show confirmation dialog
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
                            await service.updateRequestStatus(request.id, 'cancelled');
                            ref.invalidate(myRequestsProvider);
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
                      icon: const Icon(Icons.close),
                      color: Colors.red,
                      tooltip: 'Cancel Request',
                    ),
                    IconButton(
                      onPressed: () async {
                        // Show confirmation dialog
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Delete Request'),
                            content: const Text(
                              'Are you sure you want to delete this request? This cannot be undone.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirmed == true) {
                          try {
                            await service.deleteRequest(request.id);
                            ref.invalidate(myRequestsProvider);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Request deleted')),
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
                      icon: const Icon(Icons.delete),
                      color: Colors.red.withOpacity(0.7),
                      tooltip: 'Delete Request',
                    ),
                  ],
                  if (request.status == 'completed') ...[
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 24,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
