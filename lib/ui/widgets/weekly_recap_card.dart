import 'package:flutter/material.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class WeeklyRecapCard extends StatelessWidget {
  const WeeklyRecapCard({
    required this.weeklyUnlocks,
    required this.currentStreak,
    required this.onTap,
    required this.onDismiss,
    super.key,
  });

  final int weeklyUnlocks;
  final int currentStreak;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0A0E27).withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: CyberpunkTheme.neonPurple.withValues(alpha: 0.55),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: CyberpunkTheme.neonPurple.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_graph,
                  color: CyberpunkTheme.neonPurple,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR WEEK IN STATUSXP',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      weeklyUnlocks > 0
                          ? '$weeklyUnlocks unlocks • $currentStreak-day streak • Share your week'
                          : 'See your progress, standout unlocks, and next game',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Hide until next week',
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                icon: const Icon(Icons.close, color: Colors.white60, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
