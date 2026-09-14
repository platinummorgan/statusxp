class CoopFeedback {
  const CoopFeedback({required this.outcome, this.teamAgain});
  final String outcome;
  final bool? teamAgain;

  factory CoopFeedback.fromJson(Map<String, dynamic> json) => CoopFeedback(
    outcome: json['outcome'] as String,
    teamAgain: json['team_again'] as bool?,
  );
}
