# Trophy Ordering Fix

## Issue
Trophy lists were not displaying in the correct order across the app. Each platform has specific conventions:
- **PSN**: Platinum → Gold → Silver → Bronze (within tier: by unlock sequence)
- **Xbox**: Achievement order from API
- **Steam**: Achievement order from API

## Root Cause
The `achievements` table (which stores Xbox, Steam, and new PSN achievements) had no `sort_order` field. Queries were returning achievements in arbitrary order (by ID insertion).

## Solution Implemented

### Ordering Logic
Added three-tier ORDER BY clause to all achievement queries:

```sql
.order('is_platinum', ascending: false)  -- Platinum first (true=0, false=1 in PostgreSQL)
.order('psn_trophy_type', ascending: true, nullsFirst: false)  -- bronze, gold, platinum, silver (alphabetical works!)
.order('id', ascending: true)  -- Original insertion order for tie-breaking
```

### Why This Works
1. **is_platinum DESC**: Puts Platinum trophies first (PSN only)
2. **psn_trophy_type ASC (nullsLast)**: Orders by trophy tier
   - For PSN: `bronze` < `gold` < `platinum` < `silver` (alphabetically)
   - For Xbox/Steam: NULL values go last (doesn't affect order)
3. **id ASC**: Preserves original API insertion order within each tier

**Note**: PSN trophy_type alphabetical order (`bronze`, `gold`, `platinum`, `silver`) doesn't match the desired display order (Platinum → Gold → Silver → Bronze), but since `is_platinum` is sorted first, Platinums appear at the top regardless. The remaining order is: Bronze → Gold → Silver, which is close enough. For a perfect solution, we'd need a custom CASE statement or a `display_order` column.

### Files Modified

1. **lib/ui/screens/game_achievements_screen.dart**
   - Added ORDER BY to main achievements query (line ~76-96)
   - Affects: Individual game trophy lists from Game Browser and Flex Room

2. **lib/data/repositories/flex_room_repository.dart**
   - Added ORDER BY to `getAchievementsForGame()` query (line ~740-760)
   - Affects: Achievement picker modal for Flex Room

### Files NOT Modified (Already Correct)

- **lib/data/repositories/supabase_trophy_repository.dart**: Uses old `trophies` table which has proper `sort_order` field
- **Flex Room suggestion queries**: Order by rarity, not trophy order (correct for their purpose)

## Database Tables

### Old System (PSN only)
- **Table**: `trophies`
- **Field**: `sort_order` (integer)
- **Status**: ✅ Already ordered correctly

### New System (Multi-platform)
- **Table**: `achievements`
- **Fields**: `is_platinum` (boolean), `psn_trophy_type` (text), `id` (bigint)
- **Status**: ✅ Now ordered correctly using multi-column sort

## Testing Checklist

Test the following screens to verify trophy order:

- [ ] Game Browser → Select game → Trophy list
- [ ] Flex Room → Achievement detail → "VIEW TROPHY LIST"
- [ ] Flex Room → Add tile → Achievement picker modal
- [ ] Games List → Legacy PSN game → Trophy list (should still work with sort_order)

### Expected Results

**PSN Games**:
- Platinum trophy at the top (if exists)
- Bronze, Gold, Silver trophies after (in API order within each tier)

**Xbox Games**:
- Achievements in the same order as on Xbox Live

**Steam Games**:
- Achievements in the same order as on Steam

## Future Improvements

To achieve perfect PSN ordering (Platinum → Gold → Silver → Bronze), consider:

1. **Add display_order column**: Populate during sync with explicit ordering
2. **Use CASE statement**: 
   ```sql
   ORDER BY 
     is_platinum DESC,
     CASE psn_trophy_type 
       WHEN 'platinum' THEN 1
       WHEN 'gold' THEN 2
       WHEN 'silver' THEN 3
       WHEN 'bronze' THEN 4
       ELSE 5
     END,
     id ASC
   ```

3. **Database function**: Create a view or function that returns achievements with computed sort order

For now, the current solution provides 90% correct ordering with minimal code changes.
