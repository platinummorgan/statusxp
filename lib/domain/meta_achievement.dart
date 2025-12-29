/// Meta-achievement model for in-app achievements
class MetaAchievement {
  final String id;
  final String category;
  final String defaultTitle;
  final String description;
  final String? iconEmoji;
  final int sortOrder;
  final DateTime? unlockedAt;
  final String? customTitle;
  final List<String>? requiredPlatforms;

  MetaAchievement({
    required this.id,
    required this.category,
    required this.defaultTitle,
    required this.description,
    this.iconEmoji,
    required this.sortOrder,
    this.unlockedAt,
    this.customTitle,
    this.requiredPlatforms,
  });

  bool get isUnlocked => unlockedAt != null;

  String get displayTitle => customTitle ?? defaultTitle;

  factory MetaAchievement.fromJson(Map<String, dynamic> json) {
    return MetaAchievement(
      id: json['id'] as String,
      category: json['category'] as String,
      defaultTitle: json['default_title'] as String,
      description: json['description'] as String,
      iconEmoji: json['icon_emoji'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      unlockedAt: json['unlocked_at'] != null 
          ? DateTime.parse(json['unlocked_at'] as String)
          : null,
      customTitle: json['custom_title'] as String?,
      requiredPlatforms: json['required_platforms'] != null
          ? List<String>.from(json['required_platforms'] as List)
          : null,
    );
  }
}
