import 'package:supabase_flutter/supabase_flutter.dart';

class AICreditStatus {
  final bool canUse;
  final String source; // 'premium', 'pack', 'daily_free', 'none'
  final int remaining;
  final int packCredits;
  final int dailyFree;

  AICreditStatus({
    required this.canUse,
    required this.source,
    required this.remaining,
    required this.packCredits,
    required this.dailyFree,
  });

  factory AICreditStatus.fromJson(Map<String, dynamic> json) {
    return AICreditStatus(
      canUse: json['can_use'] ?? false,
      source: json['source'] ?? 'none',
      remaining: json['remaining'] ?? 0,
      packCredits: json['pack_credits'] ?? 0,
      dailyFree: json['daily_free'] ?? 0,
    );
  }

  /// Get user-friendly message about credit status
  String get statusMessage {
    if (source == 'premium') {
      return 'Premium: AI guides included';
    } else if (source == 'pack') {
      return '$packCredits pack credits';
    } else if (source == 'daily_free') {
      return '$dailyFree / 3 free today';
    } else {
      return 'No AI credits';
    }
  }

  /// Get short badge text for button
  String get badgeText {
    if (source == 'premium') {
      return '∞';
    } else if (packCredits > 0) {
      return '$packCredits';
    } else {
      return '$dailyFree / 3';
    }
  }
}

class AICreditService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Check if user can use AI and get credit status
  Future<AICreditStatus> checkCredits() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        return AICreditStatus(
          canUse: false,
          source: 'none',
          remaining: 0,
          packCredits: 0,
          dailyFree: 0,
        );
      }

      final response = await _supabase.rpc(
        'can_use_ai',
        params: {'p_user_id': userId},
      );

      return AICreditStatus.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      return AICreditStatus(
        canUse: false,
        source: 'none',
        remaining: 0,
        packCredits: 0,
        dailyFree: 0,
      );
    }
  }

  /// Get available AI pack options
  List<AIPack> getAvailablePacks() {
    return [
      AIPack(
        type: 'small',
        credits: 20,
        price: 1.99,
        title: 'AI Pack S',
        description: '20 AI uses',
        pricePerUse: 1.99 / 20,
      ),
      AIPack(
        type: 'medium',
        credits: 60,
        price: 4.99,
        title: 'AI Pack M',
        description: '60 AI uses',
        pricePerUse: 4.99 / 60,
        badge: 'BEST VALUE',
      ),
      AIPack(
        type: 'large',
        credits: 150,
        price: 9.99,
        title: 'AI Pack L',
        description: '150 AI uses',
        pricePerUse: 9.99 / 150,
      ),
    ];
  }
}

class AIPack {
  final String type;
  final int credits;
  final double price;
  final String title;
  final String description;
  final double pricePerUse;
  final String? badge;

  AIPack({
    required this.type,
    required this.credits,
    required this.price,
    required this.title,
    required this.description,
    required this.pricePerUse,
    this.badge,
  });

  String get displayPrice => '\$${price.toStringAsFixed(2)}';
  String get perUsePrice =>
      '${(pricePerUse * 100).toStringAsFixed(0)}¢ per use';
}
