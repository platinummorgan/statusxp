import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/trophy_help_request.dart';
import 'package:statusxp/services/trophy_help_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/widgets/offer_help_dialog.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:statusxp/utils/statusxp_logger.dart';

// ------------------------------
// Providers
// ------------------------------

// UI filter state
final selectedPlatformProvider = StateProvider<String?>((ref) => null);

// Open requests depend on selected platform (family = clean caching per platform)
final openRequestsProvider =
    FutureProvider.family<List<TrophyHelpRequest>, String?>((ref, platform) async {
  statusxpLog('RUN openRequestsProvider(platform=${platform ?? "all"}) container=${identityHashCode(ref)}');
  ref.onDispose(() => statusxpLog('DISPOSE openRequestsProvider(platform=${platform ?? "all"})'));
  
  final service = ref.read(trophyHelpServiceProvider);
  return service.getOpenRequests(platform: platform);
});

// My requests
final myRequestsProvider = FutureProvider<List<TrophyHelpRequest>>((ref) async {
  statusxpLog('[PROVIDER RUN] myRequestsProvider');
  final service = ref.read(trophyHelpServiceProvider);
  return service.getMyRequests();
});

// ------------------------------
// Screen
// ------------------------------

class CoopPartnersScreen extends ConsumerStatefulWidget {
  const CoopPartnersScreen({super.key});

  @override
  ConsumerState<CoopPartnersScreen> createState() => _CoopPartnersScreenState();
}

class _CoopPartnersScreenState extends ConsumerState<CoopPartnersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
        children: const [
          _FindHelpTab(key: ValueKey('find_help_tab')),
          _MyRequestsTab(key: ValueKey('my_requests_tab')),
        ],
      ),
    );
  }
}

// ------------------------------
// Find Help Tab
// ------------------------------

class _FindHelpTab extends ConsumerStatefulWidget {
  const _FindHelpTab({super.key});

  @override
  ConsumerState<_FindHelpTab> createState() => _FindHelpTabState();
}

class _FindHelpTabState extends ConsumerState<_FindHelpTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        Consumer(
          builder: (context, ref, child) {
            final selectedPlatform = ref.watch(selectedPlatformProvider);
            return _PlatformFilterBar(
              selectedPlatform: selectedPlatform,
              onChanged: (platform) =>
                  ref.read(selectedPlatformProvider.notifier).state = platform,
            );
          },
        ),

        Expanded(
          child: Consumer(
            builder: (context, ref, child) {
              final selectedPlatform = ref.watch(selectedPlatformProvider);
              final requestsAsync = ref.watch(openRequestsProvider(selectedPlatform));
              return requestsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorState(message: 'Error: $error'),
              data: (requests) {
                if (requests.isEmpty) return const _EmptyFindHelpState();

                return RefreshIndicator(
                  onRefresh: () async {
                    // family invalidate needs the param
                    ref.invalidate(openRequestsProvider(selectedPlatform));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    itemBuilder: (context, index) =>
                        _RequestCard(request: requests[index]),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class _PlatformFilterBar extends StatelessWidget {
  final String? selectedPlatform;
  final ValueChanged<String?> onChanged;

  const _PlatformFilterBar({
    required this.selectedPlatform,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                _PlatformChip(
                  label: 'All',
                  value: null,
                  selected: selectedPlatform,
                  onChanged: onChanged,
                ),
                _PlatformChip(
                  label: 'PSN',
                  value: 'psn',
                  selected: selectedPlatform,
                  onChanged: onChanged,
                ),
                _PlatformChip(
                  label: 'Xbox',
                  value: 'xbox',
                  selected: selectedPlatform,
                  onChanged: onChanged,
                ),
                _PlatformChip(
                  label: 'Steam',
                  value: 'steam',
                  selected: selectedPlatform,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _PlatformChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selectedNow) => onChanged(selectedNow ? value : null),
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

class _EmptyFindHelpState extends StatelessWidget {
  const _EmptyFindHelpState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off, size: 64, color: Colors.white.withOpacity(0.3)),
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
            style: TextStyle(color: Colors.white.withOpacity(0.4)),
          ),
        ],
      ),
    );
  }
}

// ------------------------------
// Request Card (Find Help)
// ------------------------------

class _RequestCard extends ConsumerWidget {
  final TrophyHelpRequest request;

  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platformStyle = _platformStyle(request.platform);
    final createdAgo = timeago.format(request.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1a1f3a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: CyberpunkTheme.neonCyan.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () => context.push('/coop-partners/${request.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PlatformPill(
                    label: request.platform.toUpperCase(),
                    color: platformStyle.color,
                    icon: platformStyle.icon,
                  ),
                  const Spacer(),
                  Text(
                    createdAgo,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
              if ((request.description ?? '').isNotEmpty) ...[
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
              if ((request.availability ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule,
                        size: 14, color: Colors.white.withOpacity(0.5)),
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (_) => OfferHelpDialog(request: request),
                    );

                    if (result == true) {
                      final platform = ref.read(selectedPlatformProvider);
                      ref.invalidate(openRequestsProvider(platform));
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

class _PlatformPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _PlatformPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------
// My Requests Tab
// ------------------------------

class _MyRequestsTab extends ConsumerStatefulWidget {
  const _MyRequestsTab({super.key});

  @override
  ConsumerState<_MyRequestsTab> createState() => _MyRequestsTabState();
}

class _MyRequestsTabState extends ConsumerState<_MyRequestsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final myRequestsAsync = ref.watch(myRequestsProvider);
    final theme = Theme.of(context);

    return myRequestsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonCyan),
        ),
      ),
      error: (error, _) => _ErrorState(message: 'Error: $error'),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined,
                    size: 64, color: Colors.white.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'No requests yet',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: Colors.white.withOpacity(0.6)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a request to find co-op partners',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myRequestsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) =>
                _MyRequestCard(request: requests[index]),
          ),
        );
      },
    );
  }
}

class _MyRequestCard extends ConsumerWidget {
  final TrophyHelpRequest request;

  const _MyRequestCard({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createdAgo = timeago.format(request.createdAt);
    final service = ref.read(trophyHelpServiceProvider);

    final platformStyle = _platformStyle(request.platform);
    final statusStyle = _statusStyle(request.status);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1a1f3a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: CyberpunkTheme.neonCyan.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: () => context.push('/coop-partners/${request.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PlatformPill(
                    label: request.platform.toUpperCase(),
                    color: platformStyle.color,
                    icon: platformStyle.icon,
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(label: statusStyle.label, color: statusStyle.color),
                  const Spacer(),
                  Text(
                    createdAgo,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                request.gameTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                request.achievementName,
                style: TextStyle(
                  color: CyberpunkTheme.neonCyan.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              if ((request.description ?? '').isNotEmpty) ...[
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          context.push('/coop-partners/${request.id}'),
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
                      tooltip: 'Cancel Request',
                      icon: const Icon(Icons.close),
                      color: Colors.red,
                      onPressed: () async {
                        final confirmed = await _confirm(
                          context,
                          title: 'Cancel Request',
                          message: 'Are you sure you want to cancel this request?',
                          confirmLabel: 'Yes',
                        );

                        if (confirmed != true) return;

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
                      },
                    ),
                    IconButton(
                      tooltip: 'Delete Request',
                      icon: const Icon(Icons.delete),
                      color: Colors.red.withOpacity(0.7),
                      onPressed: () async {
                        final confirmed = await _confirm(
                          context,
                          title: 'Delete Request',
                          message:
                              'Are you sure you want to delete this request? This cannot be undone.',
                          confirmLabel: 'Delete',
                          destructive: true,
                        );

                        if (confirmed != true) return;

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
                      },
                    ),
                  ],
                  if (request.status == 'completed')
                    const Icon(Icons.check_circle, color: Colors.green, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------
// Shared UI helpers
// ------------------------------

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: destructive
              ? TextButton.styleFrom(foregroundColor: Colors.red)
              : null,
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}

class _PlatformStyle {
  final Color color;
  final IconData icon;
  const _PlatformStyle(this.color, this.icon);
}

_PlatformStyle _platformStyle(String platformRaw) {
  final p = platformRaw.toLowerCase();
  switch (p) {
    case 'psn':
    case 'playstation':
      return const _PlatformStyle(Color(0xFF0070CC), Icons.sports_esports);
    case 'xbox':
      return const _PlatformStyle(Color(0xFF107C10), Icons.videogame_asset);
    case 'steam':
      return const _PlatformStyle(Color(0xFF1B2838), Icons.store);
    default:
      return const _PlatformStyle(Colors.grey, Icons.gamepad);
  }
}

class _StatusStyle {
  final Color color;
  final String label;
  const _StatusStyle(this.color, this.label);
}

_StatusStyle _statusStyle(String statusRaw) {
  switch (statusRaw) {
    case 'open':
      return const _StatusStyle(CyberpunkTheme.neonCyan, 'Open');
    case 'matched':
      return const _StatusStyle(Colors.orange, 'Matched');
    case 'completed':
      return const _StatusStyle(Colors.green, 'Completed');
    case 'cancelled':
      return const _StatusStyle(Colors.red, 'Cancelled');
    default:
      return _StatusStyle(Colors.grey, statusRaw);
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}