import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/theme/colors.dart';

const _premiumPaths = <String>{
  '/analytics',
  '/sync-intelligence',
  '/goals-pace',
  '/rival-compare',
  '/achievement-radar',
  '/premium-subscription',
};

const _guestPublicPaths = <String>{
  '/',
  '/games/browse',
  '/leaderboards',
  '/leaderboards/seasonal',
  '/leaderboards/hall-of-fame',
  '/premium-subscription',
};

/// A desktop website frame for Flutter web. Mobile retains its native app UI.
class WebAppShell extends StatelessWidget {
  const WebAppShell({
    super.key,
    required this.child,
    required this.location,
    required this.isAuthenticated,
  });

  final Widget child;
  final String location;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    final page = !isAuthenticated && location == '/'
        ? const _GuestHome()
        : !isAuthenticated && _premiumPaths.contains(location)
        ? _AccessPreview(premium: true, requestedPath: location)
        : !isAuthenticated && !_isGuestPublic(location)
        ? _AccessPreview(premium: false, requestedPath: location)
        : child;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Stack(
            children: [
              page,
              if (!isAuthenticated)
                const Positioned(
                  right: 14,
                  top: 10,
                  child: SafeArea(child: _AuthButtons(compact: true)),
                ),
            ],
          );
        }

        return Scaffold(
          backgroundColor: backgroundDark,
          body: Column(
            children: [
              _WebsiteHeader(
                location: location,
                isAuthenticated: isAuthenticated,
              ),
              Expanded(
                child: Row(
                  children: [
                    _WebsiteNavigation(location: location),
                    Expanded(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0xFF090D1D),
                        ),
                        child: ClipRect(child: page),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isGuestPublic(String path) {
    if (_guestPublicPaths.contains(path)) return true;
    return path.startsWith('/games/') || path.startsWith('/game/');
  }
}

class _WebsiteHeader extends StatelessWidget {
  const _WebsiteHeader({required this.location, required this.isAuthenticated});

  final String location;
  final bool isAuthenticated;

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 28),
    decoration: BoxDecoration(
      color: const Color(0xFF0A0E27),
      border: Border(
        bottom: BorderSide(color: accentPrimary.withValues(alpha: .18)),
      ),
    ),
    child: Row(
      children: [
        InkWell(
          onTap: () => context.go('/'),
          child: const Row(
            children: [
              Icon(
                Icons.sports_esports_rounded,
                color: accentPrimary,
                size: 30,
              ),
              SizedBox(width: 11),
              Text(
                'STATUS',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
              Text(
                'XP',
                style: TextStyle(
                  color: accentPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.3,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => context.go('/games/browse'),
          child: const Text('Explore Games'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => context.go('/leaderboards'),
          child: const Text('Leaderboards'),
        ),
        const SizedBox(width: 18),
        if (isAuthenticated)
          OutlinedButton.icon(
            onPressed: () => context.go('/settings'),
            icon: const Icon(Icons.account_circle_outlined, size: 18),
            label: const Text('My Account'),
          )
        else
          const _AuthButtons(),
      ],
    ),
  );
}

class _AuthButtons extends StatelessWidget {
  const _AuthButtons({this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!compact)
        TextButton(
          onPressed: () => context.go('/sign-in'),
          child: const Text('Sign in'),
        ),
      if (!compact) const SizedBox(width: 8),
      FilledButton(
        onPressed: () => context.go('/sign-in?mode=signup'),
        style: FilledButton.styleFrom(
          backgroundColor: accentPrimary,
          foregroundColor: backgroundDark,
        ),
        child: Text(compact ? 'Join' : 'Create free account'),
      ),
    ],
  );
}

class _WebsiteNavigation extends StatelessWidget {
  const _WebsiteNavigation({required this.location});
  final String location;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String)>[
      (Icons.home_rounded, 'Home', '/'),
      (Icons.travel_explore_rounded, 'Game catalog', '/games/browse'),
      (Icons.leaderboard_rounded, 'Leaderboards', '/leaderboards'),
      (Icons.auto_graph_rounded, 'Analytics', '/analytics'),
      (Icons.radar_rounded, 'Achievement radar', '/achievement-radar'),
      (Icons.flag_rounded, 'Goals & pace', '/goals-pace'),
    ];
    return Container(
      width: 238,
      color: const Color(0xFF0D1126),
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                selected: location == item.$3,
                selectedTileColor: accentPrimary.withValues(alpha: .12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                leading: Icon(
                  item.$1,
                  size: 21,
                  color: location == item.$3 ? accentPrimary : textSecondary,
                ),
                title: Text(
                  item.$2,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: location == item.$3 ? Colors.white : textSecondary,
                  ),
                ),
                trailing: _premiumPaths.contains(item.$3)
                    ? const Icon(
                        Icons.workspace_premium_rounded,
                        size: 15,
                        color: accentWarning,
                      )
                    : null,
                onTap: () => context.go(item.$3),
              ),
            ),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Track PlayStation, Xbox, and Steam in one place.',
              style: TextStyle(color: textMuted, fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestHome extends StatelessWidget {
  const _GuestHome();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 54, vertical: 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR GAMING LIFE,\nALL IN ONE PLACE.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 680,
                child: Text(
                  'Explore games and global rankings now. Create a free account when you are ready to sync your profiles, track achievements, and build your StatusXP identity.',
                  style: TextStyle(
                    color: textSecondary,
                    fontSize: 18,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 14,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go('/games/browse'),
                    icon: const Icon(Icons.explore_rounded),
                    label: const Text('Explore the game catalog'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accentPrimary,
                      foregroundColor: backgroundDark,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/leaderboards'),
                    icon: const Icon(Icons.leaderboard_rounded),
                    label: const Text('View leaderboards'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 58),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth > 850
                      ? (constraints.maxWidth - 40) / 3
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      _FeatureCard(
                        width: width,
                        icon: Icons.public_rounded,
                        title: 'Browse freely',
                        body:
                            'Search the complete cross-platform game catalog without creating an account.',
                      ),
                      _FeatureCard(
                        width: width,
                        icon: Icons.emoji_events_rounded,
                        title: 'See who leads',
                        body:
                            'Explore community rankings across StatusXP, trophies, Xbox, and Steam.',
                      ),
                      _FeatureCard(
                        width: width,
                        icon: Icons.insights_rounded,
                        title: 'Unlock your stats',
                        body:
                            'Sign up to sync your profiles and turn achievement history into one unified dashboard.',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.width,
    required this.icon,
    required this.title,
    required this.body,
  });
  final double width;
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: surfaceLight.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .07)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accentPrimary, size: 30),
        const SizedBox(height: 20),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 9),
        Text(body, style: const TextStyle(color: textSecondary, height: 1.5)),
      ],
    ),
  );
}

class _AccessPreview extends StatelessWidget {
  const _AccessPreview({required this.premium, required this.requestedPath});
  final bool premium;
  final String requestedPath;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.transparent,
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          padding: const EdgeInsets.all(42),
          decoration: BoxDecoration(
            color: surfaceDark,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: (premium ? accentWarning : accentPrimary).withValues(
                alpha: .35,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                premium
                    ? Icons.workspace_premium_rounded
                    : Icons.person_add_alt_1_rounded,
                color: premium ? accentWarning : accentPrimary,
                size: 52,
              ),
              const SizedBox(height: 22),
              Text(
                premium
                    ? 'Go further with StatusXP Premium'
                    : 'Make StatusXP yours',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                premium
                    ? 'This is a Premium feature. Create an account to start tracking your gaming history and see the Premium tools available to you.'
                    : 'This page uses your personal gaming data. Create a free account to connect a platform, sync achievements, and view your own progress.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: textSecondary,
                  fontSize: 16,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => context.go(
                  '/sign-in?mode=signup&from=${Uri.encodeComponent(requestedPath)}',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: premium ? accentWarning : accentPrimary,
                  foregroundColor: backgroundDark,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 17,
                  ),
                ),
                child: const Text('Create free account'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.go(
                  '/sign-in?from=${Uri.encodeComponent(requestedPath)}',
                ),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
