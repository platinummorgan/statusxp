# Dashboard Platform Query Refactor

## Summary
Updated analytics and dashboard queries to join the `platforms` table and return `platform_name` directly, eliminating frontend platform_id-to-name mapping.

## Changes Made

### 1. Analytics Repository (COMPLETED)
**File:** `lib/data/repositories/analytics_repository.dart`

**Before:**
```dart
// Hardcoded platform_id lists
final psnResponse = await _client
    .from('user_achievements')
    .select('id')
    .eq('user_id', userId)
    .inFilter('platform_id', [1, 2, 5, 9])  // PSN platforms
    .count();

final steamResponse = await _client
    .from('user_achievements')
    .select('id')
    .eq('user_id', userId)
    .eq('platform_id', 5)  // BUG: 5 is PS3, not Steam!
    .count();
```

**After:**
```dart
// Single RPC call with JOIN to platforms table
final response = await _client
    .rpc('get_platform_achievement_counts', params: {
      'p_user_id': userId,
    });

// Maps platform_code (PS5, STEAM, etc.) to categories
for (final platform in platforms) {
  final code = (platform['platform_code'] as String).toUpperCase();
  final count = platform['earned_rows'] as int;
  
  if (['PS5', 'PS4', 'PS3', 'PSVITA'].contains(code)) {
    psnCount += count;
  } else if (['XBOX360', 'XBOXONE', 'XBOXSERIESX'].contains(code)) {
    xboxCount += count;
  } else if (code == 'STEAM') {
    steamCount += count;
  }
}
```

**Bug Fixed:** Steam was querying `platform_id = 5` (PS3) instead of `platform_id = 4` (Steam)

### 2. SQL Function (CREATED)
**File:** `supabase/migrations/1009_create_platform_achievement_counts.sql`

Created RPC function that returns platform data with names:

```sql
CREATE OR REPLACE FUNCTION get_platform_achievement_counts(p_user_id uuid)
RETURNS TABLE (
  platform_id bigint,
  platform_code text,
  platform_name text,
  earned_rows int
)
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id as platform_id,
    p.code as platform_code,
    p.name as platform_name,
    count(*)::int as earned_rows
  FROM user_achievements ua
  JOIN platforms p ON p.id = ua.platform_id
  WHERE ua.user_id = p_user_id
  GROUP BY p.id, p.code, p.name
  ORDER BY p.id;
END;
$$;
```

**Benefits:**
- Single source of truth (platforms table)
- Returns platform_code (PS5, STEAM) and platform_name (PlayStation 5, Steam)
- No hardcoded platform_id lists in Dart code
- Correct Steam platform_id (4) used

## Dashboard Repository (ANALYSIS)

### Current Architecture
**File:** `lib/data/repositories/supabase_dashboard_repository.dart`

The dashboard is currently structured to query three specific platform families:

```dart
Future<DashboardStats> getDashboardStats(String userId) async {
  final results = await Future.wait([
    _getStatusXPTotal(userId),
    _getPlatformStats(userId, 1, psnPlatforms: [1, 2, 5, 9]), // PSN
    _getPlatformStats(userId, 2, xboxPlatforms: [10, 11, 12]), // Xbox
    _getPlatformStats(userId, 4), // Steam
    _getUserProfile(userId),
  ]);
  
  return DashboardStats(
    psnStats: results[1],
    xboxStats: results[2],
    steamStats: results[3],
    // ...
  );
}
```

**Domain Model:** `lib/domain/dashboard_stats.dart`
```dart
class DashboardStats {
  final PlatformStats psnStats;
  final PlatformStats xboxStats;
  final PlatformStats steamStats;
}
```

### Refactor Options

#### Option A: Keep Current Structure (Recommended)
- Dashboard is intentionally designed around PSN/Xbox/Steam families
- No changes needed - architecture matches business requirements
- `_getPlatformStats()` can stay as-is with platform_id lists

#### Option B: Full Refactor to Dynamic Platforms
Would require:
1. Change `DashboardStats` to use `List<PlatformFamilyStats>`
2. Update UI to render dynamic platform cards
3. Define platform family groupings in database
4. Major UI/UX changes to dashboard screen

**Recommendation:** Keep dashboard as-is. The PSN/Xbox/Steam structure is intentional for the main dashboard view. The analytics query refactor (already completed) provides dynamic platform support where needed.

## Testing Checklist

- [ ] Deploy migration 1009 to staging/production
- [ ] Verify analytics pie chart shows correct Steam counts (not PS3 data)
- [ ] Verify PSN counts include PS5+PS4+PS3+PSVITA
- [ ] Verify Xbox counts include 360+One+SeriesX
- [ ] Check dashboard still displays PSN/Xbox/Steam stats correctly
- [ ] Verify no console errors in analytics screen

## Migration Deployment

```bash
# Apply migration 1009
supabase db push

# Or via SQL editor:
# Run: supabase/migrations/1009_create_platform_achievement_counts.sql
```

## Verification Query

Test the new RPC function:
```sql
SELECT * FROM get_platform_achievement_counts('your-user-id'::uuid);

-- Should return:
-- platform_id | platform_code | platform_name    | earned_rows
-- 1           | PS5          | PlayStation 5    | 100
-- 2           | PS4          | PlayStation 4    | 250
-- 4           | STEAM        | Steam            | 150
-- etc.
```

## Notes

- **Analytics query:** Now uses dynamic platform JOIN (flexible for future platforms)
- **Dashboard query:** Keeps PSN/Xbox/Steam structure (intentional for main UI)
- **Critical bug fixed:** Steam was querying platform_id 5 (PS3) instead of 4 (Steam)
- **Performance:** Single RPC call replaces 3 separate COUNT queries in analytics
- **Maintainability:** Platform names now come from database, not hardcoded in Dart
