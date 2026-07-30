import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';
import 'package:statusxp/services/analytics_service.dart';

Future<void> showPremiumUpgradeDialog(
  BuildContext context, {
  required String message,
  String title = 'Premium Required',
  String dismissLabel = 'Not Now',
  String upgradeLabel = 'Upgrade',
  String source = 'generic_gate',
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF1A1F3A),
      title: Row(
        children: [
          const Icon(Icons.star, color: CyberpunkTheme.goldNeon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(
          onPressed: () {
            AnalyticsService().logCustomEvent(
              eventName: 'premium_offer_dismissed',
              parameters: {'source': source},
            );
            Navigator.pop(dialogContext);
          },
          child: Text(dismissLabel),
        ),
        ElevatedButton(
          onPressed: () {
            AnalyticsService().logCustomEvent(
              eventName: 'premium_offer_accepted',
              parameters: {'source': source},
            );
            Navigator.pop(dialogContext);
            context.push(
              Uri(
                path: '/premium-subscription',
                queryParameters: {'source': source},
              ).toString(),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: CyberpunkTheme.neonPurple,
          ),
          child: Text(upgradeLabel),
        ),
      ],
    ),
  );
}
