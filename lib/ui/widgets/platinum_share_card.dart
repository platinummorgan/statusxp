import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:statusxp/domain/platinum_card.dart';

/// Deterministic overlay: AI never draws names, earned dates, scores or rarity.
class PlatinumShareCard extends StatelessWidget {
  const PlatinumShareCard({
    super.key,
    required this.items,
    this.background,
    this.quote = '',
    this.showRarity = true,
    this.showNotable = true,
    this.alignment = Alignment.center,
    this.zoom = 1,
    this.showTrophy = true,
  });
  final List<PlatinumCardData> items;
  final ImageProvider? background;
  final String quote;
  final bool showRarity, showNotable;
  final Alignment alignment;
  final double zoom;
  final bool showTrophy;
  static const width = 720.0, height = 1000.0;
  static const silver = Color(0xffe4edf5);
  @override
  Widget build(BuildContext context) {
    final first = items.first;
    final collection = items.length > 1;
    return SizedBox(
      width: width,
      height: height,
      child: DefaultTextStyle(
        style: const TextStyle(color: silver, fontFamily: 'PlatinumDisplay'),
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xff080c12)),
              if (background != null)
                Transform.scale(
                  scale: zoom,
                  child: Image(
                    image: background!,
                    fit: BoxFit.cover,
                    alignment: alignment,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: Color(0xff111b29)),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0, .38, .66, 1],
                    colors: [
                      Color(0xcc020509),
                      Color(0x3303070b),
                      Color(0xdd030609),
                      Color(0xff030609),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: const Color(0xff233447),
                          backgroundImage: first.avatarUrl != null
                              ? NetworkImage(first.avatarUrl!)
                              : null,
                          child: first.avatarUrl == null
                              ? Text(
                                  first.playerName.trim().isEmpty
                                      ? 'P'
                                      : first.playerName.characters.first
                                            .toUpperCase(),
                                  style: const TextStyle(
                                    fontFamily: 'PlatinumDisplay',
                                    fontSize: 22,
                                    color: silver,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                first.playerName.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 24,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              Text(
                                collection
                                    ? 'PLAYSTATION COLLECTION'
                                    : first.platform.toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'sans-serif',
                                  fontSize: 12,
                                  letterSpacing: 2,
                                  color: Color(0xffa9bbc9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      collection
                          ? 'A COLLECTION WORTH CELEBRATING'
                          : 'PLATINUM UNLOCKED',
                      style: const TextStyle(fontSize: 15, letterSpacing: 4),
                    ),
                    Text(
                      collection
                          ? '${items.length} PLATINUMS'
                          : '#${first.number}',
                      style: TextStyle(
                        fontSize: collection ? 64 : 112,
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 20),
                        ],
                      ),
                    ),
                    if (!collection && showRarity && first.rarity != null)
                      Text(
                        '${first.rarity!.toStringAsFixed(1)}% EARNED · PlayStation rarity',
                        style: const TextStyle(fontSize: 16),
                      ),
                    const Spacer(),
                    if (!collection && showTrophy)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Image.asset(
                          'assets/images/platinum_trophy.png',
                          height: 205,
                          width: 170,
                          fit: BoxFit.contain,
                        ),
                      ),
                    if (collection) ...[
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          child: Row(
                            children: [
                              if (item.coverUrl != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    item.coverUrl!,
                                    width: 48,
                                    height: 62,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) =>
                                        const SizedBox(width: 48, height: 62),
                                  ),
                                ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.gameName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 23),
                                    ),
                                    Text(
                                      '#${item.number} · ${item.earnedAt == null ? 'Earned date unavailable' : DateFormat('d MMM yyyy').format(item.earnedAt!.toLocal())}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xffa9bbc9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Text(
                        first.gameName.toUpperCase(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 43,
                          height: 1.05,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                    if (quote.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 17),
                        child: Text(
                          '“${quote.trim()}”',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    const SizedBox(height: 14),
                    const Divider(color: Color(0xff65717c)),
                    if (!collection)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                first.trophyName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              first.earnedAt == null
                                  ? 'Earned date unavailable'
                                  : DateFormat(
                                      'd MMM yyyy',
                                    ).format(first.earnedAt!.toLocal()),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    if (!collection &&
                        showNotable &&
                        first.notable.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'NOTABLE TROPHIES',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, letterSpacing: 3),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final trophy in first.notable.take(3))
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Column(
                                  children: [
                                    if (trophy.iconUrl != null)
                                      Image.network(
                                        trophy.iconUrl!,
                                        height: 38,
                                        width: 38,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.emoji_events,
                                          color: silver,
                                          size: 38,
                                        ),
                                      ),
                                    const SizedBox(height: 5),
                                    Text(
                                      trophy.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                    Text(
                                      '${trophy.rarity.toStringAsFixed(1)}%',
                                      style: const TextStyle(fontSize: 26),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'PlayStation rarity',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xffa9bbc9),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            height: 66,
                            width: 66,
                          ),
                        ),
                        const Text(
                          'statusxp.com',
                          style: TextStyle(
                            fontSize: 17,
                            color: Color(0xffb6c8d6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
