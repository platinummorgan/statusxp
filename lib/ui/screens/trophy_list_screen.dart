import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:statusxp/domain/game.dart';
import 'package:statusxp/domain/trophy.dart';
import 'package:statusxp/data/repositories/supabase_trophy_repository.dart';
import 'package:statusxp/theme/colors.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/ui/widgets/glass_panel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Trophy List Screen - Shows all trophies for a game
class TrophyListScreen extends ConsumerStatefulWidget {
  const TrophyListScreen({super.key, required this.game});

  final Game game;

  @override
  ConsumerState<TrophyListScreen> createState() => _TrophyListScreenState();
}

class _TrophyListScreenState extends ConsumerState<TrophyListScreen> {
  late Future<List<Trophy>> _trophiesFuture;

  @override
  void initState() {
    super.initState();
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser!.id;
    final repo = SupabaseTrophyRepository(supabase);
    _trophiesFuture = repo.getTrophiesForGame(userId, int.parse(widget.game.id));
  }

  Color _getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'bronze':
        return const Color(0xFFCD7F32);
      case 'silver':
        return const Color(0xFFC0C0C0);
      case 'gold':
        return const Color(0xFFFFD700);
      case 'platinum':
        return accentPrimary;
      default:
        return textSecondary;
    }
  }

  IconData _getTierIcon(String tier) {
    if (tier.toLowerCase() == 'platinum') {
      return Icons.emoji_events;
    }
    return Icons.circle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.game.name.toUpperCase(),
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            shadows: CyberpunkTheme.neonGlow(color: CyberpunkTheme.neonCyan),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: CyberpunkTheme.neonCyan,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: CyberpunkTheme.gradientBackground(),
        child: FutureBuilder<List<Trophy>>(
          future: _trophiesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(CyberpunkTheme.neonCyan),
                ),
              );
            }

            if (snapshot.hasError) {
              return const Center(
                child: GlassPanel(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, color: CyberpunkTheme.neonPink, size: 48),
                        SizedBox(height: 16),
                        Text(
                          'ERROR LOADING TROPHIES',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

          final trophies = snapshot.data ?? [];

            if (trophies.isEmpty) {
              return const SafeArea(
                child: Center(
                  child: GlassPanel(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'NO TROPHIES FOUND',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 100),
            itemCount: trophies.length,
            itemBuilder: (context, index) {
              final trophy = trophies[index];
              final tierColor = _getTierColor(trophy.tier);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: GlassPanel(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                      // Trophy icon with neon border
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: trophy.earned
                                ? tierColor
                                : Colors.white24,
                            width: trophy.earned ? 2 : 1,
                          ),
                          boxShadow: trophy.earned ? [
                            BoxShadow(
                              color: tierColor.withOpacity(0.5),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ] : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: trophy.iconUrl != null
                              ? Image.network(
                                  trophy.iconUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    _getTierIcon(trophy.tier),
                                    color: trophy.earned
                                        ? tierColor
                                        : Colors.white24,
                                    size: 28,
                                  ),
                                  color: trophy.earned
                                      ? null
                                      : Colors.grey.withValues(alpha: 0.3),
                                  colorBlendMode:
                                      trophy.earned ? null : BlendMode.saturation,
                                )
                              : Icon(
                                  _getTierIcon(trophy.tier),
                                  color: trophy.earned
                                      ? tierColor
                                      : Colors.white24,
                                  size: 28,
                                ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Trophy info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Trophy name
                            Text(
                              trophy.hidden && !trophy.earned
                                  ? 'HIDDEN TROPHY'
                                  : trophy.name.toUpperCase(),
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: trophy.earned ? Colors.white : Colors.white60,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),

                            if (trophy.description != null &&
                                (!trophy.hidden || trophy.earned)) ...[
                              const SizedBox(height: 4),
                              Text(
                                trophy.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: trophy.earned
                                      ? Colors.white70
                                      : Colors.white38,
                                  fontSize: 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],

                            const SizedBox(height: 8),

                            // Trophy tier and rarity
                            Row(
                              children: [
                                // Tier badge with neon glow
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: trophy.earned
                                        ? tierColor.withOpacity(0.2)
                                        : Colors.white10,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: trophy.earned
                                          ? tierColor
                                          : Colors.white24,
                                      width: trophy.earned ? 1.5 : 1,
                                    ),
                                    boxShadow: trophy.earned ? [
                                      BoxShadow(
                                        color: tierColor.withOpacity(0.3),
                                        blurRadius: 4,
                                      ),
                                    ] : null,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _getTierIcon(trophy.tier),
                                        size: 12,
                                        color: trophy.earned
                                            ? tierColor
                                            : Colors.white38,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        trophy.tier.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: trophy.earned
                                              ? tierColor
                                              : Colors.white38,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Rarity pill with cyan accent
                                if (trophy.rarityGlobal != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: CyberpunkTheme.neonCyan.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: CyberpunkTheme.neonCyan,
                                        width: 1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: CyberpunkTheme.neonCyan.withOpacity(0.3),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      '${trophy.rarityGlobal!.toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: CyberpunkTheme.neonCyan,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Earned checkmark with glow
                      if (trophy.earned)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: tierColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: tierColor.withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: tierColor,
                            size: 24,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ),
  ),
);
}
}
