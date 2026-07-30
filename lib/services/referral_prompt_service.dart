import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/theme/cyberpunk_theme.dart';

class ReferralPromptService {
  static const _lastPromptKey = 'referral_prompt_last_at';
  static const cooldown = Duration(days: 7);

  Future<bool> canShow({DateTime? now, SharedPreferences? preferences}) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final last = DateTime.tryParse(prefs.getString(_lastPromptKey) ?? '');
    return last == null || (now ?? DateTime.now()).difference(last) >= cooldown;
  }

  Future<void> markShown({
    DateTime? now,
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    await prefs.setString(
      _lastPromptKey,
      (now ?? DateTime.now()).toIso8601String(),
    );
  }

  Future<bool> showIfEligible(
    BuildContext context, {
    required String source,
  }) async {
    if (!await canShow() || !context.mounted) return false;
    await markShown();
    AnalyticsService().logCustomEvent(
      eventName: 'referral_prompt_viewed',
      parameters: {'source': source},
    );
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F3A),
        title: const Row(
          children: [
            Icon(Icons.group_add, color: CyberpunkTheme.neonGreen),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Know another achievement hunter?',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        content: const Text(
          'Give them 10 AI guides—and get 10 when they complete their first sync.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AnalyticsService().logCustomEvent(
                eventName: 'referral_prompt_dismissed',
                parameters: {'source': source},
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () {
              AnalyticsService().logCustomEvent(
                eventName: 'referral_prompt_accepted',
                parameters: {'source': source},
              );
              Navigator.pop(dialogContext);
              context.push('/invite?source=$source');
            },
            icon: const Icon(Icons.share),
            label: const Text('Invite a friend'),
          ),
        ],
      ),
    );
    return true;
  }
}
