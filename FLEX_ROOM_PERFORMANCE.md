# Flex Room Performance Analysis

## Current Performance Issues

### 1. **N+1 Query Problem (MAJOR)**

The Flex Room makes **numerous sequential database queries**:

```dart
// getFlexRoomData() calls:
1. flex_room_data query (config)
2. _getAchievementTile() for flexOfAllTime → game_titles query
3. _getAchievementTile() for rarestFlex → game_titles query
4. _getAchievementTile() for mostTimeSunk → game_titles query
5. _getAchievementTile() for sweattiestPlatinum → game_titles query
6. Loop: _getAchievementTile() for each superlative → game_titles query EACH
7. _getRecentNotableAchievements() → game_titles query FOR EACH item (up to 5)
```

**Problem**: Each `_getAchievementTile()` calls `_buildFlexTile()`, which makes a **separate** `game_titles` query:

```dart
Future<FlexTile?> _buildFlexTile(Map<String, dynamic> userAchievementRow) async {
  // ...
  final gameData = await _client
      .from('game_titles')
      .select('name, cover_url')
      .eq('id', gameId)
      .maybeSingle(); // ← SEPARATE QUERY FOR EACH TILE!
  // ...
}
```

**Impact**: For a typical Flex Room with:
- 4 featured tiles
- 5 superlatives
- 5 recent flexes
= **14+ separate game_titles queries** (all sequential!)

### 2. **Missing Foreign Key Joins**

The queries already fetch achievements with `inner()` join, but then fetch game data separately:

```dart
// Current (SLOW):
final response = await _client.from('user_achievements')
    .select('achievements!inner(...)') // Get achievement
    // Then later...
await _client.from('game_titles').select('...').eq('id', gameId); // Get game

// Could be (FAST):
final response = await _client.from('user_achievements')
    .select('achievements!inner(*, game_titles!inner(*))') // Get both at once
```

### 3. **Separate Profile Query**

The screen also loads user profile separately:

```dart
final profile = await supabase.from('profiles').select(...).eq('id', userId).single();
final titleData = await supabase.from('user_selected_title').select(...).eq('user_id', userId).maybeSingle();
```

These could be combined or at least done in parallel with the Flex Room data.

## Optimization Opportunities

### HIGH IMPACT - Fix N+1 Queries

**Option A: Batch Game Queries**
```dart
Future<FlexRoomData?> getFlexRoomData(String userId) async {
  // ... existing code ...
  
  // Collect all game IDs first
  final gameIds = <int>{};
  if (flexOfAllTime != null) gameIds.add(flexOfAllTime.gameId);
  // ... collect all game IDs ...
  
  // Batch query all games at once
  final gamesMap = await _getGamesBatch(gameIds.toList());
  
  // Build tiles using cached game data
}
```

**Option B: Join game_titles in Initial Query** (BEST)
```dart
final response = await _client
    .from('user_achievements')
    .select('''
      id,
      achievement_id,
      earned_at,
      achievements!inner(
        id,
        name,
        icon_url,
        rarity_global,
        platform,
        psn_trophy_type,
        game_titles!inner(  ← ADD THIS JOIN
          id,
          name,
          cover_url
        )
      )
    ''')
    .eq('achievement_id', achievementId)
    .eq('user_id', userId)
    .maybeSingle();
```

Then `_buildFlexTile()` doesn't need separate game query.

### MEDIUM IMPACT - Parallelize Queries

Instead of sequential awaits, use `Future.wait()`:

```dart
// Current (SEQUENTIAL):
final rarestFlex = await _getRarestAchievement(userId);
final mostTimeSunk = await _getMostTimeSunkGame(userId);
final sweattiestPlatinum = await _getSweattiestPlatinum(userId);

// Optimized (PARALLEL):
final results = await Future.wait([
  _getRarestAchievement(userId),
  _getMostTimeSunkGame(userId),
  _getSweattiestPlatinum(userId),
]);
```

### LOW IMPACT - Cache User Profile

Profile data rarely changes. Could cache in provider or load once.

## Recommended Implementation

### Priority 1: Add game_titles Join

**Files to modify:**
1. `lib/data/repositories/flex_room_repository.dart`
   - Update `_getAchievementTile()` to join game_titles
   - Update `_buildFlexTile()` to extract game data from nested response
   - Update `_getRecentNotableAchievements()` to join game_titles
   - Update other achievement queries

**Expected improvement**: Reduce from ~14 queries to ~8 queries (50% reduction)

### Priority 2: Parallelize Independent Queries

Use `Future.wait()` for featured tiles that don't depend on each other.

**Expected improvement**: Reduce total load time by 30-40%

### Priority 3: Database View/Function

Create a database function that returns complete Flex Room data in one query:

```sql
CREATE FUNCTION get_flex_room_complete(user_id UUID)
RETURNS JSON AS $$
  -- Single query that joins everything
  -- Returns complete JSON with all tiles and game data
$$ LANGUAGE plpgsql;
```

**Expected improvement**: Reduce to 1 query, load time cut by 70-80%

## Estimated Impact

**Current**: ~14 sequential queries, ~2-3 seconds load time
**After Option B**: ~8 queries (some parallel), ~1-1.5 seconds load time  
**After DB Function**: 1 query, ~0.5 seconds load time

## Trade-offs

- **Option A (Batch)**: Easiest to implement, moderate improvement
- **Option B (Joins)**: Medium complexity, good improvement, keeps logic in Dart
- **Option C (DB Function)**: Most complex, best performance, moves logic to SQL

I recommend starting with **Option B (joins)** as it provides significant improvement without major refactoring.
