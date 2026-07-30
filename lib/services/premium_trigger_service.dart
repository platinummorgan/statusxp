import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statusxp/services/analytics_service.dart';
import 'package:statusxp/ui/widgets/premium_upgrade_dialog.dart';

enum PremiumTrigger {
  syncCooldown,
  aiLimit,
  weeklyRecap,
  streak,
  nearCompletion,
}

class PremiumOffer {
  const PremiumOffer({
    required this.source,
    required this.title,
    required this.message,
    required this.upgradeLabel,
  });

  final String source;
  final String title;
  final String message;
  final String upgradeLabel;
}

PremiumOffer premiumOfferFor(
  PremiumTrigger trigger, {
  String? platform,
  String? gameName,
}) {
  return switch (trigger) {
    PremiumTrigger.syncCooldown => PremiumOffer(
      source: 'sync_cooldown_${platform ?? 'unknown'}',
      title: 'Sync sooner with Premium',
      message:
          'You have reached the ${platform ?? 'platform'} sync cooldown. Premium cuts cooldowns to as little as 15 minutes and raises daily sync limits.',
      upgradeLabel: 'See Faster Syncs',
    ),
    PremiumTrigger.aiLimit => const PremiumOffer(
      source: 'ai_limit',
      title: 'Keep getting achievement help',
      message:
          'Premium includes unlimited AI achievement guides, so you can keep going without buying individual credit packs.',
      upgradeLabel: 'Get Unlimited Guides',
    ),
    PremiumTrigger.weeklyRecap => const PremiumOffer(
      source: 'weekly_recap',
      title: 'Turn this week into a plan',
      message:
          'Premium adds pace coaching, goals, deeper trends, and achievement radar based on your gaming history.',
      upgradeLabel: 'Unlock My Insights',
    ),
    PremiumTrigger.streak => const PremiumOffer(
      source: 'streak_momentum',
      title: 'Keep your momentum growing',
      message:
          'Premium goals and pace coaching turn your streak into a practical plan for finishing more games.',
      upgradeLabel: 'Build My Plan',
    ),
    PremiumTrigger.nearCompletion => PremiumOffer(
      source: 'near_completion',
      title: 'Finish ${gameName ?? 'this game'} faster',
      message:
          'Premium achievement radar and unlimited guides help identify the best remaining unlocks and your quickest path to completion.',
      upgradeLabel: 'Show My Finish Plan',
    ),
  };
}

class PremiumTriggerService {
  static const _globalKey = 'premium_offer_last_global_at';
  static const _sourcePrefix = 'premium_offer_last_source_';
  static const globalCooldown = Duration(hours: 24);
  static const sourceCooldown = Duration(days: 7);

  Future<bool> canShow(
    String source, {
    DateTime? now,
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final current = now ?? DateTime.now();
    final global = DateTime.tryParse(prefs.getString(_globalKey) ?? '');
    final sourceLast = DateTime.tryParse(
      prefs.getString('$_sourcePrefix$source') ?? '',
    );
    if (global != null && current.difference(global) < globalCooldown) {
      return false;
    }
    return sourceLast == null ||
        current.difference(sourceLast) >= sourceCooldown;
  }

  Future<void> markShown(
    String source, {
    DateTime? now,
    SharedPreferences? preferences,
  }) async {
    final prefs = preferences ?? await SharedPreferences.getInstance();
    final timestamp = (now ?? DateTime.now()).toIso8601String();
    await Future.wait([
      prefs.setString(_globalKey, timestamp),
      prefs.setString('$_sourcePrefix$source', timestamp),
    ]);
  }

  Future<bool> showIfEligible(
    BuildContext context, {
    required PremiumOffer offer,
  }) async {
    if (!await canShow(offer.source) || !context.mounted) return false;
    await markShown(offer.source);
    AnalyticsService().logCustomEvent(
      eventName: 'premium_trigger_impression',
      parameters: {'source': offer.source},
    );
    if (!context.mounted) return false;
    await showPremiumUpgradeDialog(
      context,
      source: offer.source,
      title: offer.title,
      message: offer.message,
      upgradeLabel: offer.upgradeLabel,
    );
    return true;
  }
}
