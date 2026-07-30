import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/providers/connected_platforms_provider.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class FirstSyncOnboardingScreen extends ConsumerStatefulWidget {
  const FirstSyncOnboardingScreen({super.key});

  @override
  ConsumerState<FirstSyncOnboardingScreen> createState() =>
      _FirstSyncOnboardingScreenState();
}

class _FirstSyncOnboardingScreenState
    extends ConsumerState<FirstSyncOnboardingScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsService().logCustomEvent(
      eventName: 'first_sync_onboarding_viewed',
    );
  }

  void _selectPlatform(String platform, bool connected) {
    AnalyticsService().logCustomEvent(
      eventName: 'first_sync_platform_selected',
      parameters: {'platform': platform, 'already_connected': connected},
    );

    final route = switch (platform) {
      'psn' => '/psn-sync',
      'xbox' => '/xbox-sync',
      'steam' => connected ? '/steam-sync' : '/steam-connect',
      _ => '/settings',
    };
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final connectedAsync = ref.watch(connectedPlatformsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(title: const Text('GET STARTED')),
      body: SafeArea(
        child: connectedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => _content(const <String>{}),
          data: _content,
        ),
      ),
    );
  }

  Widget _content(Set<String> connected) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Icon(Icons.auto_graph, color: CyberpunkTheme.neonCyan, size: 56),
        const SizedBox(height: 16),
        const Text(
          'See your gaming story come alive',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Connect one platform and run your first sync. StatusXP will build your score, game library, achievements, and personalized next moves.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.45),
        ),
        const SizedBox(height: 24),
        const _StepStrip(),
        const SizedBox(height: 28),
        _PlatformCard(
          name: 'PlayStation',
          description:
              'Import trophies, platinums, rarity, and recent progress.',
          icon: Icons.sports_esports,
          color: const Color(0xFF00A8E1),
          connected: connected.contains('psn'),
          onTap: () => _selectPlatform('psn', connected.contains('psn')),
        ),
        const SizedBox(height: 14),
        _PlatformCard(
          name: 'Xbox',
          description: 'Import achievements, Gamerscore, and game progress.',
          icon: Icons.videogame_asset,
          color: const Color(0xFF52B043),
          connected: connected.contains('xbox'),
          onTap: () => _selectPlatform('xbox', connected.contains('xbox')),
        ),
        const SizedBox(height: 14),
        _PlatformCard(
          name: 'Steam',
          description: 'Import your Steam library and unlocked achievements.',
          icon: Icons.computer,
          color: const Color(0xFF66C0F4),
          connected: connected.contains('steam'),
          onTap: () => _selectPlatform('steam', connected.contains('steam')),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => context.push('/settings'),
          child: const Text('Advanced connection settings'),
        ),
      ],
    );
  }
}

class _StepStrip extends StatelessWidget {
  const _StepStrip();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _Step(number: '1', label: 'Connect'),
        ),
        Icon(Icons.chevron_right, color: Colors.white38),
        Expanded(
          child: _Step(number: '2', label: 'Sync'),
        ),
        Icon(Icons.chevron_right, color: Colors.white38),
        Expanded(
          child: _Step(number: '3', label: 'Explore'),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.label});
  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: CyberpunkTheme.neonPurple,
          child: Text(number, style: const TextStyle(color: Colors.white)),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.connected,
    required this.onTap,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool connected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0A0E27),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.55)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: color.withValues(alpha: 0.16),
                child: Icon(icon, color: color, size: 27),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(color: Colors.white60),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  if (connected)
                    const Icon(Icons.check_circle, color: Colors.greenAccent),
                  const SizedBox(height: 4),
                  Text(
                    connected ? 'SYNC' : 'CONNECT',
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
