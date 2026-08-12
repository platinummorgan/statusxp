import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/domain/game_overview.dart';
import 'package:statusxp/domain/game_ref.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/state/statusxp_providers.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class GameOverviewScreen extends ConsumerStatefulWidget {
  final GameRef gameRef;

  const GameOverviewScreen({super.key, required this.gameRef});

  @override
  ConsumerState<GameOverviewScreen> createState() => _GameOverviewScreenState();
}

class _GameOverviewScreenState extends ConsumerState<GameOverviewScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService().logCustomEvent(
      eventName: 'game_overview_viewed',
      parameters: {
        'platform_id': widget.gameRef.platformId,
        'platform_game_id': widget.gameRef.platformGameId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(gameOverviewProvider(widget.gameRef));
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text('GAME OVERVIEW'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/games'),
        ),
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: overview.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _MessageState(
            icon: Icons.cloud_off,
            title: 'Unable to load this game',
            message: error.toString(),
            actionLabel: 'Try again',
            onAction: () =>
                ref.invalidate(gameOverviewProvider(widget.gameRef)),
          ),
          data: (game) => game == null
              ? _MessageState(
                  icon: Icons.search_off,
                  title: 'Game not found',
                  message:
                      'This game may have been removed or the link is incorrect.',
                  actionLabel: 'Browse games',
                  onAction: () => context.go('/games/browse'),
                )
              : _GameOverviewBody(game: game),
        ),
      ),
    );
  }
}

class _GameOverviewBody extends StatelessWidget {
  final GameOverview game;

  const _GameOverviewBody({required this.game});

  @override
  Widget build(BuildContext context) {
    final platform = game.ref.platform!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 680;
                  final cover = _Cover(url: game.coverUrl ?? game.iconUrl);
                  final details = _HeroDetails(
                    game: game,
                    platformLabel: platform.label,
                  );
                  return compact
                      ? Column(
                          children: [
                            cover,
                            const SizedBox(height: 20),
                            details,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            cover,
                            const SizedBox(width: 28),
                            Expanded(child: details),
                          ],
                        );
                },
              ),
              const SizedBox(height: 24),
              if (game.isOwned)
                _ProgressPanel(game: game)
              else
                const _LibraryNotice(),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  final query = Uri(
                    queryParameters: {
                      'platform_id': game.ref.platformId.toString(),
                      'platform_game_id': game.ref.platformGameId,
                      'name': game.name,
                      'platform': game.ref.platform!.code,
                      if (game.coverUrl != null) 'cover': game.coverUrl!,
                    },
                  ).query;
                  context.go(
                    '/game/${Uri.encodeComponent(game.ref.platformGameId)}/achievements?$query',
                  );
                },
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('View achievements'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GameRouteNotFoundScreen extends StatelessWidget {
  const GameRouteNotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0A0E27),
    appBar: AppBar(title: const Text('GAME NOT FOUND')),
    body: _MessageState(
      icon: Icons.link_off,
      title: 'Invalid game link',
      message: 'The platform or game identifier in this link is not valid.',
      actionLabel: 'Browse games',
      onAction: () => context.go('/games/browse'),
    ),
  );
}

class _Cover extends StatelessWidget {
  final String? url;
  const _Cover({this.url});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: SizedBox(
      width: 220,
      height: 290,
      child: url == null || url!.isEmpty
          ? const ColoredBox(
              color: Color(0xFF1A1F3A),
              child: Icon(
                Icons.videogame_asset,
                size: 72,
                color: Colors.white24,
              ),
            )
          : Image.network(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const ColoredBox(
                color: Color(0xFF1A1F3A),
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 64,
                  color: Colors.white24,
                ),
              ),
            ),
    ),
  );
}

class _HeroDetails extends StatelessWidget {
  final GameOverview game;
  final String platformLabel;
  const _HeroDetails({required this.game, required this.platformLabel});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        game.name,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 10),
      Chip(label: Text(platformLabel)),
      if (game.developer != null) ...[
        const SizedBox(height: 12),
        Text(
          'Developed by ${game.developer}',
          style: const TextStyle(color: Colors.white70),
        ),
      ],
      if (game.publisher != null)
        Text(
          'Published by ${game.publisher}',
          style: const TextStyle(color: Colors.white70),
        ),
      if (game.description != null && game.description!.isNotEmpty) ...[
        const SizedBox(height: 18),
        Text(
          game.description!,
          style: const TextStyle(color: Colors.white70, height: 1.5),
        ),
      ],
    ],
  );
}

class _ProgressPanel extends StatelessWidget {
  final GameOverview game;
  const _ProgressPanel({required this.game});

  @override
  Widget build(BuildContext context) => Card(
    color: const Color(0xFF151A35),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'YOUR PROGRESS',
            style: TextStyle(
              color: CyberpunkTheme.neonCyan,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (game.completionPercentage / 100).clamp(0, 1),
            minHeight: 10,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _Stat(
                label: 'Complete',
                value: '${game.completionPercentage.toStringAsFixed(0)}%',
              ),
              _Stat(
                label: 'Achievements',
                value: '${game.achievementsEarned}/${game.achievementsTotal}',
              ),
              if (game.currentScore > 0)
                _Stat(label: 'Platform score', value: '${game.currentScore}'),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white60)),
    ],
  );
}

class _LibraryNotice extends StatelessWidget {
  const _LibraryNotice();
  @override
  Widget build(BuildContext context) => const Card(
    color: Color(0xFF151A35),
    child: Padding(
      padding: EdgeInsets.all(20),
      child: Text(
        'You do not have synced progress for this game yet.',
        style: TextStyle(color: Colors.white70),
      ),
    ),
  );
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white60),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    ),
  );
}
