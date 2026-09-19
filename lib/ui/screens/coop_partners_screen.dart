import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/services/trophy_help_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/widgets/offer_help_dialog.dart';
import 'package:statusxp/ui/widgets/coop_session_summary.dart';
import 'package:statusxp/ui/widgets/coop_game_artwork.dart';
import 'package:timeago/timeago.dart' as timeago;

class CoopPartnersScreen extends ConsumerWidget {
  const CoopPartnersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    return _CoopHub(key: ValueKey(userId), userId: userId);
  }
}

class _CoopHub extends ConsumerStatefulWidget {
  const _CoopHub({super.key, required this.userId});
  final String? userId;
  @override
  ConsumerState<_CoopHub> createState() => _CoopHubState();
}

class _CoopHubState extends ConsumerState<_CoopHub> {
  static const _pageSize = 24;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  final _sentOffers = <String>{};
  Timer? _debounce;
  CoopFeed _feed = CoopFeed.discover;
  String? _platform;
  List<CoopEntry> _entries = [];
  bool _loading = true;
  bool _more = false;
  bool _failed = false;
  int _generation = 0;
  int _offset = 0;
  int _artEpoch = 0;
  final _covers = <CoopGameKey, String>{};
  final _confirming = <String>{};

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  @override
  void dispose() {
    _generation++;
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    _debounce?.cancel();
    if (!reset && _loading) return;
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      if (reset) {
        _artEpoch++;
        _covers.clear();
        _entries = [];
        _offset = 0;
        _more = false;
      }
    });
    try {
      final rows = await ref
          .read(trophyHelpServiceProvider)
          .getCoopPage(
            feed: _feed,
            platform: _platform,
            search: _search.text,
            offset: _offset,
            limit: _pageSize,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _offset += rows.length;
        final ids = _entries.map((e) => e.request.id).toSet();
        _entries = [..._entries, ...rows.where((e) => ids.add(e.request.id))];
        _more = rows.length == _pageSize;
        _loading = false;
      });
      unawaited(_loadArtwork(rows, _artEpoch));
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  void _filterChanged() {
    _artEpoch++;
    _covers.clear();
    _generation++; // Ignore old results immediately, including during debounce.
    _debounce?.cancel();
    setState(() {
      _entries = [];
      _offset = 0;
      _more = false;
      _loading = true;
      _failed = false;
    });
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _load(reset: true),
    );
  }

  Future<void> _loadArtwork(List<CoopEntry> rows, int epoch) async {
    try {
      final covers = await ref
          .read(trophyHelpServiceProvider)
          .getCoopArtwork(rows.map((e) => e.request).toList());
      if (mounted && epoch == _artEpoch && covers.isNotEmpty) {
        setState(() => _covers.addAll(covers));
      }
    } catch (_) {
      // Artwork is optional; keep the request and its actions available.
    }
  }

  Future<void> _reconfirm(CoopEntry entry) async {
    if (_confirming.contains(entry.request.id)) return;
    final past = entry.request.scheduledAt?.isBefore(DateTime.now()) ?? false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Still looking for partners?'),
        content: Text(
          past
              ? 'The scheduled time has passed. Confirm that you still need help and switch this request to flexible timing. Let any confirmed partners know about the change.'
              : 'Confirm that this request is still active and the availability you posted is current.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(past ? 'Confirm flexible timing' : 'Confirm request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _confirming.add(entry.request.id));
    try {
      await ref
          .read(trophyHelpServiceProvider)
          .reconfirmRequest(entry.request.id, clearPastSchedule: past);
      if (mounted) await _load(reset: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not confirm the request. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming.remove(entry.request.id));
    }
  }

  Future<void> _requestHelp() async {
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What are you working toward?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Choose a game from your library, open its achievements, then select Find Partner on an achievement you still need. Add your availability so partners know when to join.',
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.videogame_asset),
                label: const Text('Choose a game'),
              ),
            ],
          ),
        ),
      ),
    );
    if (proceed != true || !mounted) return;
    await context.push('/games');
    if (mounted) _load(reset: true);
  }

  Future<void> _open(CoopEntry entry) async {
    await context.push('/coop-partners/${entry.request.id}');
    if (mounted) _load(reset: true);
  }

  Future<void> _offer(CoopEntry entry) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => OfferHelpDialog(request: entry.request),
    );
    if (sent == true && mounted) {
      setState(() => _sentOffers.add(entry.request.id));
    }
  }

  Future<void> _delete(CoopEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete request?'),
        content: const Text('This removes the request and its offers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(trophyHelpServiceProvider).deleteRequest(entry.request.id);
      if (mounted) _load(reset: true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete the request. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      appBar: AppBar(
        title: const Text('Co-op hub'),
        backgroundColor: const Color(0xFF0B1020),
        actions: [
          IconButton(
            tooltip: 'Refresh requests',
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _search,
                  maxLength: 100,
                  onChanged: (_) => _filterChanged(),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Search games or achievements',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _search.clear();
                              _filterChanged();
                            },
                            icon: const Icon(Icons.close),
                          ),
                    filled: true,
                    fillColor: const Color(0xFF171F36),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final p in <String?, String>{
                        null: 'All platforms',
                        'psn': 'PlayStation',
                        'xbox': 'Xbox',
                        'steam': 'Steam',
                      }.entries)
                        ChoiceChip(
                          label: Text(p.value),
                          selected: _platform == p.key,
                          onSelected: (_) {
                            setState(() => _platform = p.key);
                            _load(reset: true);
                          },
                        ),
                    ],
                  ),
                ),
              ),
              DefaultTabController(
                length: 3,
                child: TabBar(
                  onTap: (index) {
                    setState(() => _feed = CoopFeed.values[index]);
                    _load(reset: true);
                  },
                  tabs: const [
                    Tab(text: 'Find partners'),
                    Tab(text: 'My requests'),
                    Tab(text: 'My offers'),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _load(reset: true),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 760 ? 2 : 1;
                      return CustomScrollView(
                        controller: _scroll,
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(child: _intro()),
                          if (_entries.isEmpty && !_loading && !_failed)
                            SliverToBoxAdapter(child: _empty()),
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            sliver: SliverList.builder(
                              itemCount: (_entries.length / columns).ceil(),
                              itemBuilder: (context, row) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    for (
                                      var column = 0;
                                      column < columns;
                                      column++
                                    ) ...[
                                      if (column > 0) const SizedBox(width: 16),
                                      Expanded(
                                        child:
                                            row * columns + column <
                                                _entries.length
                                            ? _card(
                                                _entries[row * columns +
                                                    column],
                                              )
                                            : const SizedBox(),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: _loading
                                    ? const CircularProgressIndicator()
                                    : _failed
                                    ? Column(
                                        children: [
                                          const Text(
                                            'Could not load requests. Please try again.',
                                          ),
                                          const SizedBox(height: 8),
                                          OutlinedButton.icon(
                                            onPressed: () => _load(),
                                            icon: const Icon(Icons.refresh),
                                            label: const Text('Retry'),
                                          ),
                                        ],
                                      )
                                    : _more
                                    ? OutlinedButton(
                                        onPressed: () => _load(),
                                        child: const Text('Load more'),
                                      )
                                    : const SizedBox(),
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
      ),
    );
  }

  Widget _intro() => Container(
    margin: const EdgeInsets.all(16),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      gradient: const LinearGradient(
        colors: [Color(0xFF242A55), Color(0xFF122E3C)],
      ),
      border: Border.all(color: CyberpunkTheme.neonCyan.withValues(alpha: .25)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BETTER TOGETHER',
          style: TextStyle(
            color: CyberpunkTheme.neonCyan,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          switch (_feed) {
            CoopFeed.discover => 'Make the next unlock a team effort.',
            CoopFeed.requests => 'Your goals. Your next teammates.',
            CoopFeed.offers => 'Keep track of the help you offered.',
          },
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(switch (_feed) {
          CoopFeed.discover =>
            'Find a shared goal, compare availability, and help each other finish.',
          CoopFeed.requests =>
            'Review offers, connect with an accepted helper, and celebrate completed goals.',
          CoopFeed.offers =>
            'Revisit your offers and open a request for partner details and the next step.',
        }, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _requestHelp,
          icon: const Icon(Icons.add),
          label: const Text('Request help'),
        ),
      ],
    ),
  );

  Widget _empty() => Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      children: [
        const Icon(
          Icons.handshake_outlined,
          size: 40,
          color: CyberpunkTheme.neonCyan,
        ),
        const SizedBox(height: 12),
        Text(
          _search.text.isNotEmpty || _platform != null
              ? 'No requests match these filters.'
              : switch (_feed) {
                  CoopFeed.discover => 'Start the next team-up.',
                  CoopFeed.requests => 'Your next goal starts here.',
                  CoopFeed.offers => 'You have not offered help yet.',
                },
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          _search.text.isNotEmpty || _platform != null
              ? 'Try another game, achievement, or platform.'
              : _feed == CoopFeed.offers
              ? 'Browse Find partners and offer help on a goal you can tackle.'
              : 'Use Request help to choose an achievement from your library.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );

  Widget _card(CoopEntry entry) {
    final request = entry.request;
    final owner = (request.profileId ?? request.userId) == widget.userId;
    final sent = entry.offerStatus != null || _sentOffers.contains(request.id);
    final canOffer = !owner && !sent && request.status == 'open';
    final old = request.needsConfirmation(DateTime.now());
    final color = switch (request.platform) {
      'psn' => const Color(0xFF75B6FF),
      'xbox' => const Color(0xFF88DC84),
      _ => CyberpunkTheme.neonCyan,
    };
    final status = switch (request.status) {
      'assigned' || 'matched' => 'Partner found',
      'completed' => 'Completed',
      'cancelled' => 'Cancelled',
      'closed' => 'Closed',
      _ => old ? 'Needs confirmation' : 'Looking for help',
    };
    final offerLabel = switch (entry.offerStatus) {
      'accepted' => 'Your offer accepted',
      'declined' => 'Your offer declined',
      'pending' => 'Your offer pending',
      'completed' => 'Help completed',
      _ => 'Offer sent',
    };
    return Container(
      key: ValueKey('request-${request.id}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF171F36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _badge(
                request.platform == 'psn'
                    ? 'PlayStation'
                    : request.platform == 'xbox'
                    ? 'Xbox'
                    : request.platform == 'steam'
                    ? 'Steam'
                    : request.platform,
                color,
              ),
              _badge(status, Colors.white70),
              if (sent && !owner) _badge(offerLabel, Colors.white70),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              CoopGameArtwork(
                url:
                    _covers[(
                      platform: request.platform,
                      gameId: request.gameId,
                    )],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  request.gameTitle,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.emoji_events_outlined, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.achievementName,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (request.description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              request.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schedule, size: 18, color: Colors.white60),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.availability?.trim().isNotEmpty == true
                      ? request.availability!
                      : 'Availability not shared yet',
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CoopSessionSummary(request: request),
          const SizedBox(height: 8),
          Text(
            'Posted ${timeago.format(request.createdAt)}${old && request.status == 'open' ? ' · Check availability before planning' : ''}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          if (request.lastConfirmedAt != null)
            Text(
              'Owner confirmed ${timeago.format(request.lastConfirmedAt!)}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (owner && request.status == 'open')
                OutlinedButton.icon(
                  onPressed: _confirming.contains(request.id)
                      ? null
                      : () => _reconfirm(entry),
                  icon: const Icon(Icons.update, size: 18),
                  label: const Text('Still looking'),
                ),
              if (canOffer)
                FilledButton.icon(
                  onPressed: () => _offer(entry),
                  icon: const Icon(Icons.handshake_outlined, size: 18),
                  label: const Text('Offer help'),
                ),
              OutlinedButton(
                onPressed: () => _open(entry),
                child: Text(
                  owner
                      ? 'Manage request'
                      : entry.offerStatus == 'accepted'
                      ? 'View partner details'
                      : 'View request',
                ),
              ),
              if (owner)
                TextButton(
                  onPressed: () => _delete(entry),
                  child: const Text('Delete'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
    ),
  );
}
