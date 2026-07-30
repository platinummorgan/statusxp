import 'package:flutter/material.dart';
import 'package:statusxp/domain/next_best_action.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class NextBestActionCard extends StatelessWidget {
  const NextBestActionCard({
    required this.action,
    required this.onTap,
    required this.onDismiss,
    super.key,
  });

  final NextBestAction action;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0E27).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: CyberpunkTheme.neonGreen.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: CyberpunkTheme.neonGreen.withValues(alpha: 0.16),
            blurRadius: 18,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: CyberpunkTheme.neonGreen, size: 18),
              const SizedBox(width: 8),
              const Text(
                'YOUR NEXT MOVE',
                style: TextStyle(
                  color: CyberpunkTheme.neonGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Hide until tomorrow',
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white60, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            action.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            action.description,
            style: const TextStyle(color: Colors.white70, height: 1.35),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward, size: 17),
            label: Text(action.buttonLabel),
            style: FilledButton.styleFrom(
              backgroundColor: CyberpunkTheme.neonGreen,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
