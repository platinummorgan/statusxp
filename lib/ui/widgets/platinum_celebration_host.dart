import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/state/platinum_card_providers.dart';
import 'package:statusxp/domain/platinum_card.dart';

/// Lives inside the authenticated and security-reconnect gates.
class PlatinumCelebrationHost extends ConsumerStatefulWidget {
  const PlatinumCelebrationHost({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<PlatinumCelebrationHost> createState() =>
      _PlatinumCelebrationHostState();
}

class _PlatinumCelebrationHostState
    extends ConsumerState<PlatinumCelebrationHost> {
  final _shown = <String>{};
  Future<void> _show(PlatinumCelebration batch) async {
    if (!mounted || _shown.contains(batch.id)) return;
    _shown.add(batch.id);
    final choose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: MediaQuery.of(context).disableAnimations
            ? const Icon(Icons.emoji_events, size: 54, color: Color(0xffbceeff))
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: .7, end: 1),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeOutBack,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: const Icon(
                  Icons.emoji_events,
                  size: 54,
                  color: Color(0xffbceeff),
                ),
              ),
        title: Text(batch.title, textAlign: TextAlign.center),
        content: Text(
          batch.historical
              ? '${batch.count} platinums added to your collection. Choose one to celebrate, or make a collection card.'
              : batch.count == 1
              ? '${batch.items.first.gameName}\nCreate something worthy of the achievement.'
              : 'Choose an individual platinum or select up to four for a collection card.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create share card'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    try {
      await ref.read(platinumCardRepositoryProvider).acknowledge(batch.id);
    } catch (_) {
      /* Durable pending batch is retried on a later session. */
    }
    if (!mounted) return;
    if (choose == true) context.push('/platinum-cards', extra: batch.items);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(platinumCelebrationProvider, (_, next) {
      final batch = next.asData?.value;
      if (batch != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _show(batch);
        });
      }
    });
    return widget.child;
  }
}
