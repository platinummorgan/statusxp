/// Adapt catalog rows to the rich trophy card while keeping platform metadata.
Map<String, dynamic> achievementPresentation(
  Map<String, dynamic> row,
  int index,
) {
  final metadata = row['metadata'] as Map? ?? {};
  bool flag(Object? value) =>
      ['true', '1', 'yes', 'hidden'].contains(value.toString().toLowerCase());
  final rarity = (row['rarity_global'] as num?)?.toDouble();
  return {
    ...row,
    'id': row['platform_achievement_id'],
    'is_earned': row['earned'] == true,
    'psn_trophy_type': metadata['psn_trophy_type'],
    'xbox_gamerscore': metadata['xbox_gamerscore'],
    'xbox_is_secret': flag(metadata['xbox_is_secret']),
    'is_hidden':
        flag(metadata['hidden']) ||
        flag(metadata['psn_hidden']) ||
        flag(metadata['steam_hidden']),
    'rarity_band': rarity == null
        ? null
        : rarity < 1
        ? 'ULTRA_RARE'
        : rarity < 5
        ? 'VERY_RARE'
        : rarity < 15
        ? 'RARE'
        : rarity < 50
        ? 'UNCOMMON'
        : 'COMMON',
    '_original_index': index,
  };
}

String achievementGroup(Map<String, dynamic> row) {
  final metadata = row['metadata'] as Map? ?? {};
  final group = metadata['trophy_group_id']?.toString() ?? 'default';
  if (group != 'default' && group.isNotEmpty) {
    return metadata['dlc_name']?.toString() ?? 'DLC $group';
  }
  if (metadata['is_dlc'] == true && metadata['dlc_name'] != null) {
    return metadata['dlc_name'].toString();
  }
  return 'Base Game';
}

int compareAchievementPresentation(
  Map<String, dynamic> a,
  Map<String, dynamic> b,
  String platform,
) {
  final groupA = achievementGroup(a);
  final groupB = achievementGroup(b);
  if (groupA != groupB) {
    if (groupA == 'Base Game') return -1;
    if (groupB == 'Base Game') return 1;
    return groupA.compareTo(groupB);
  }
  int order(Map<String, dynamic> row) {
    final metadata = row['metadata'] as Map? ?? {};
    final value = platform.startsWith('ps')
        ? metadata['sort_order'] ?? row['platform_achievement_id']
        : platform.startsWith('xbox')
        ? metadata['display_order'] ?? row['platform_achievement_id']
        : metadata['steam_display_order'] ?? metadata['sort_order'];
    return int.tryParse(value?.toString() ?? '') ?? 2147483647;
  }

  final native = order(a).compareTo(order(b));
  return native != 0
      ? native
      : (a['_original_index'] as int).compareTo(b['_original_index'] as int);
}
