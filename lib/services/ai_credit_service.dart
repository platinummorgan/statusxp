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
      return 'Premium: Unlimited AI';
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

  /// Consume one AI credit (call this when generating AI guide)
  Future<AICreditStatus> consumeCredit() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase.rpc(
        'consume_ai_credit',
        params: {'p_user_id': userId},
      );

      return AICreditStatus.fromJson(response as Map<String, dynamic>);
    } catch (e) {
      rethrow;
    }
  }

  /// Add pack credits after successful purchase
  Future<bool> addPackCredits({
    required String packType, // 'small', 'medium', 'large'
    required int credits,
    required double price,
    required String platform,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase.rpc(
        'add_ai_pack_credits',
        params: {
          'p_user_id': userId,
          'p_pack_type': packType,
          'p_credits': credits,
          'p_price': price,
          'p_platform': platform,
        },
      );

      final result = response as Map<String, dynamic>;
      return result['success'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get available AI pack options
  List<AIPack> getAvailablePacks() {
    return [
      AIPack(
        type: 'small',
        credits: 10,
        price: 1.99,
        title: 'AI Pack S',
        description: '10 AI uses',
        pricePerUse: 0.20, // ~20¢ per use
      ),
      AIPack(
        type: 'medium',
        credits: 30,
        price: 4.99,
        title: 'AI Pack M',
        description: '30 AI uses',
        pricePerUse: 0.17, // ~17¢ per use
        badge: 'BEST VALUE',
      ),
      AIPack(
        type: 'large',
        credits: 75,
        price: 9.99,
        title: 'AI Pack L',
        description: '75 AI uses',
        pricePerUse: 0.13, // ~13¢ per use
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
  String get perUsePrice => '${(pricePerUse * 100).toStringAsFixed(0)}¢ per use';
}
