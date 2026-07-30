import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:statusxp/services/analytics_service.dart';

class ReferralSummary {
  const ReferralSummary({
    required this.code,
    required this.pending,
    required this.rewarded,
    required this.creditsEarned,
    required this.redeemedCode,
  });

  final String code;
  final int pending;
  final int rewarded;
  final int creditsEarned;
  final String? redeemedCode;

  factory ReferralSummary.fromJson(Map<String, dynamic> json) {
    return ReferralSummary(
      code: json['code']?.toString() ?? '',
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      rewarded: (json['rewarded'] as num?)?.toInt() ?? 0,
      creditsEarned: (json['credits_earned'] as num?)?.toInt() ?? 0,
      redeemedCode: json['redeemed_code']?.toString(),
    );
  }
}

class ReferralService {
  ReferralService(this._client);
  final SupabaseClient _client;

  Future<ReferralSummary> getSummary() async {
    final data = await _client.rpc('get_my_referral_summary');
    return ReferralSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> redeem(String code) async {
    await _client.rpc(
      'redeem_referral_code',
      params: {'p_code': code.trim().toUpperCase()},
    );
    AnalyticsService().logCustomEvent(eventName: 'referral_code_redeemed');
  }

  Future<bool> finalizeAfterFirstSync() async {
    final data = await _client.rpc('finalize_my_referral_reward');
    final rewarded = data is Map && data['rewarded'] == true;
    if (rewarded) {
      AnalyticsService().logCustomEvent(eventName: 'referral_reward_earned');
    }
    return rewarded;
  }
}
