# Meta Achievement System Revamp - Implementation Plan

## Current State Analysis

**Database:** 
- 50 meta achievements defined in `033_create_meta_achievements_tables.sql`
- Checking logic in `achievement_checker_service.dart` (897 lines)
- Categories: rarity (10), volume (10), streak (5), platform (5), completion (5), time (5), variety (5), meta (5)

**Issues Found:**
1. Several achievements need removal (Touch Grass, Birthday Buff, Profile Pimp, Fresh Flex, Speedrun Finish)
2. Some need adjustment (Power Session: 100→50, So Close It Hurts: PS incompatible)
3. Genre-based achievements broken (no genre data or detection not working)
4. **Critical: Rank Up IRL not triggering despite meeting criteria (15K XP)**
5. Night Owl + Early Grind conflict (auto-unlock both)

---

## Phase 1: Platform-Aware System

### Goal: Only show achievements user can actually earn based on connected platforms

### Implementation:

**1. Add Platform Requirements to Database**
```sql
ALTER TABLE meta_achievements ADD COLUMN required_platforms TEXT[];
-- Examples:
-- PSN only: ['psn']
-- Xbox only: ['xbox']  
-- Multi-platform: ['psn', 'xbox'] (requires both)
-- All platforms: ['psn', 'xbox', 'steam']
-- Any platform: NULL or [] (default)
```

**2. Create Platform Detection Provider**
```dart
// lib/providers/connected_platforms_provider.dart
final connectedPlatformsProvider = FutureProvider<Set<String>>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  final supabase = Supabase.instance.client;
  
  final profile = await supabase
    .from('profiles')
    .select('psn_online_id, xbox_gamertag, steam_id')
    .eq('id', userId)
    .single();
  
  final platforms = <String>{};
  if (profile['psn_online_id'] != null) platforms.add('psn');
  if (profile['xbox_gamertag'] != null) platforms.add('xbox');
  if (profile['steam_id'] != null) platforms.add('steam');
  
  return platforms;
});
```

**3. Filter Achievements by Platform**
```dart
// In meta_achievement_repository.dart
Future<List<MetaAchievement>> getAllAchievements(
  String userId, 
  Set<String> connectedPlatforms
) async {
  final achievements = await _client
    .from('meta_achievements')
    .select()
    .order('sort_order');
  
  // Filter achievements based on platform requirements
  return achievements
    .where((achievement) {
      final required = achievement['required_platforms'] as List?;
      if (required == null || required.isEmpty) return true; // Any platform
      
      // Check if user has all required platforms
      return required.every((p) => connectedPlatforms.contains(p));
    })
    .map((json) => MetaAchievement.fromJson(json))
    .toList();
}
```

**4. Update UI**
- Achievements screen filters based on connected platforms
- Show "Connect more platforms" prompt if achievements are hidden
- Optional: "View All" toggle to see what they're missing

---

## Phase 2: Fix/Remove Broken Achievements

### Database Updates

```sql
-- 1. DELETE ACHIEVEMENTS THAT NEED REMOVAL
DELETE FROM meta_achievements WHERE id IN (
  'touch_grass',      -- Anti-engagement
  'birthday_buff',    -- No birthdate data
  'profile_pimp',     -- Feature doesn't exist
  'fresh_flex',       -- Impossible if you have rare achievement
  'speedrun_finish'   -- Promotes shovelware
);

-- 2. UPDATE POWER SESSION (100 → 50)
UPDATE meta_achievements 
SET description = 'Earn 50 trophies/achievements within 24 hours'
WHERE id = 'power_session';

-- 3. ADD PLATFORM REQUIREMENT TO SO_CLOSE_IT_HURTS (Xbox/Steam only)
UPDATE meta_achievements
SET required_platforms = ARRAY['xbox', 'steam'],
    description = 'Have a game with all but 1 achievement remaining (Xbox/Steam)'
WHERE id = 'so_close_it_hurts';

-- 4. FIX CONFLICTING TIME ACHIEVEMENTS
UPDATE meta_achievements
SET description = 'Earn a trophy/achievement between 2–6 AM local time'
WHERE id = 'night_owl';

UPDATE meta_achievements
SET description = 'Earn a trophy/achievement between 6–9 AM local time'  
WHERE id = 'early_grind';
```

### Code Updates

```dart
// In achievement_checker_service.dart

// Fix Power Session check (line ~45)
Future<List<String>> _checkPowerSession() async {
  // Change from 100 to 50
  final result = await _client.rpc('check_power_session', params: {
    'p_user_id': userId,
    'p_threshold': 50, // Changed from 100
  });
  // ...
}

// Fix So Close It Hurts - skip for PSN
Future<List<String>> _checkSoCloseItHurts(String userId) async {
  // Only check Xbox and Steam games
  final almostComplete = await _client
    .from('user_games')
    .select('id, xbox_total_achievements, xbox_achievements_earned, platform_id')
    .eq('user_id', userId)
    .inFilter('platform_id', [3, 4, 10, 11, 12]); // Xbox and Steam platform IDs
  
  final hasAlmostComplete = almostComplete.any((game) => 
    game['xbox_total_achievements'] != null &&
    game['xbox_achievements_earned'] == game['xbox_total_achievements'] - 1
  );
  // ...
}

// Fix Night Owl / Early Grind timing
Future<List<String>> _checkNightOwl() async {
  // Check for 2 AM - 6 AM (non-inclusive of Early Grind hours)
  // ...
}

Future<List<String>> _checkEarlyGrind() async {
  // Check for 6 AM - 9 AM  
  // ...
}
```

---

## Phase 3: Fix Genre-Based Achievements

### Investigate Genre Data

1. **Check if genres exist:**
```sql
SELECT COUNT(*), genres 
FROM game_titles 
WHERE genres IS NOT NULL 
GROUP BY genres;
```

2. **If no data, populate from external API or manual tagging**

3. **Fix detection logic:**
```dart
Future<List<String>> _checkVarietyAchievements() async {
  // Fearless - horror games
  final horrorGames = await _client
    .from('user_games')
    .select('game_titles!inner(genres)')
    .eq('user_id', userId)
    .eq('has_platinum', true)
    .containedBy('game_titles.genres', ['Horror', 'Survival Horror']);
  
  if (horrorGames.length >= 1) {
    await _unlockAchievement(userId, 'fearless');
  }
  
  // Similar for Big Brain Energy (Puzzle genre)
  // ...
}
```

---

## Phase 4: Fix Critical Bug - Rank Up IRL Not Triggering

### Investigation Steps:

1. **Check current implementation:**
```dart
// In _checkMetaAchievements()
if (!unlocked.contains('rank_up_irl')) {
  final statusXP = stats['totalStatusXP'] as int;
  if (statusXP >= 10000) {
    await _unlockAchievement(userId, 'rank_up_irl');
  }
}
```

2. **Verify stats calculation:**
```dart
// In _getUserStats()
// Is totalStatusXP being calculated correctly?
final statusXP = await _client
  .from('user_games')
  .select('statusxp_effective')
  .eq('user_id', userId);

final total = statusXP.fold<int>(0, (sum, game) => 
  sum + ((game['statusxp_effective'] as num?)?.toInt() ?? 0)
);
```

3. **Check if achievement checker is being called:**
- When does `checkAndUnlockAchievements()` run?
- Only on Achievements screen load?
- Should also run after sync completes!

**Add Trigger After Sync:**
```dart
// In sync completion callbacks
await ref.read(achievementCheckerServiceProvider)
  .checkAndUnlockAchievements(userId);
```

---

## Phase 5: Category-Based Filtering

### Update Achievement Categories

**New Categories:**
- `psn_only` - PSN-specific achievements
- `xbox_only` - Xbox-specific achievements
- `steam_only` - Steam-specific achievements
- `multi_platform` - Requires 2+ platforms
- `all_platforms` - Requires all 3 platforms
- `general` - Available to anyone regardless of platforms

**Update Database:**
```sql
UPDATE meta_achievements SET category = 'psn_only'
WHERE id IN ('welcome_trophy_room');

UPDATE meta_achievements SET category = 'xbox_only'
WHERE id IN ('welcome_gamerscore');

UPDATE meta_achievements SET category = 'steam_only'
WHERE id IN ('welcome_pc_grind');

UPDATE meta_achievements SET category = 'multi_platform'
WHERE id IN ('triforce');

UPDATE meta_achievements SET category = 'all_platforms'
WHERE id IN ('cross_platform_conqueror', 'systems_online');
```

---

## Testing Plan

### 1. Platform Filtering Test
- User with only PSN connected should NOT see Xbox/Steam-specific achievements
- User with PSN + Xbox should see multi-platform but NOT all-platform achievements
- User with all 3 should see everything

### 2. Achievement Triggering Test
- Delete user_meta_achievements for test user
- Verify Rank Up IRL triggers at 10K+ XP
- Verify Power Session triggers at 50 achievements in 24h
- Verify genre-based achievements trigger correctly

### 3. Sync Integration Test
- Complete a sync
- Verify achievement checker runs automatically
- Verify new achievements unlock if criteria met

---

## Implementation Order

1. **CRITICAL FIRST:** Fix Rank Up IRL bug (why isn't it triggering?)
2. Remove 5 bad achievements from database
3. Fix Power Session threshold (100→50)
4. Fix time window conflicts (Night Owl/Early Grind)
5. Add platform requirements column to database
6. Implement platform detection provider
7. Filter achievements by connected platforms in UI
8. Investigate and fix genre data/detection
9. Add achievement checker to sync completion flow
10. Testing and validation

---

## Migration SQL File

Create: `d:\Dev\statusxp\supabase\migrations\041_revamp_meta_achievements.sql`

```sql
-- Meta Achievement System Revamp
-- Based on user feedback and testing

-- 1. Remove broken/undesirable achievements
DELETE FROM meta_achievements WHERE id IN (
  'touch_grass',
  'birthday_buff', 
  'profile_pimp',
  'fresh_flex',
  'speedrun_finish'
);

-- 2. Update Power Session threshold
UPDATE meta_achievements 
SET description = 'Earn 50 trophies/achievements within 24 hours'
WHERE id = 'power_session';

-- 3. Add platform requirements
ALTER TABLE meta_achievements ADD COLUMN IF NOT EXISTS required_platforms TEXT[];

-- Mark platform-specific achievements
UPDATE meta_achievements SET required_platforms = ARRAY['xbox', 'steam']
WHERE id = 'so_close_it_hurts';

UPDATE meta_achievements SET required_platforms = ARRAY['psn']
WHERE id = 'welcome_trophy_room';

UPDATE meta_achievements SET required_platforms = ARRAY['xbox']
WHERE id = 'welcome_gamerscore';

UPDATE meta_achievements SET required_platforms = ARRAY['steam']
WHERE id = 'welcome_pc_grind';

UPDATE meta_achievements SET required_platforms = ARRAY['psn', 'xbox', 'steam']
WHERE id IN ('triforce', 'cross_platform_conqueror', 'systems_online');

-- 4. Fix time achievement descriptions
UPDATE meta_achievements
SET description = 'Earn a trophy/achievement between 2–6 AM local time'
WHERE id = 'night_owl';

UPDATE meta_achievements
SET description = 'Earn a trophy/achievement between 6–9 AM local time'  
WHERE id = 'early_grind';

-- 5. Update helper function for Power Session
CREATE OR REPLACE FUNCTION check_power_session(p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
  max_trophies_in_24h INTEGER;
BEGIN
  SELECT MAX(trophy_count) INTO max_trophies_in_24h
  FROM (
    SELECT 
      ut1.earned_at,
      COUNT(*) as trophy_count
    FROM user_trophies ut1
    JOIN user_trophies ut2 ON ut2.user_id = ut1.user_id
      AND ut2.earned_at BETWEEN ut1.earned_at AND ut1.earned_at + INTERVAL '24 hours'
    WHERE ut1.user_id = p_user_id
    GROUP BY ut1.earned_at
  ) windows;
  
  RETURN COALESCE(max_trophies_in_24h, 0) >= 50; -- Changed from 100 to 50
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

Ready to start implementation?
