# New Cross-Platform Dashboard Implementation

## ✅ Completed

### 1. Data Models
- Created `DashboardStats` model with cross-platform metrics
- Created `PlatformStats` model for platform-specific data (PSN, Xbox, Steam)
- Located: `lib/domain/dashboard_stats.dart`

### 2. Database Layer
- Created `SupabaseDashboardRepository` to fetch dashboard data
- Uses existing StatusXP views: `user_statusxp_summary`
- Queries achievement counts, game counts, and platinum counts per platform
- Located: `lib/data/repositories/supabase_dashboard_repository.dart`

### 3. State Management
- Added `dashboardRepositoryProvider` and `dashboardStatsProvider` to Riverpod
- Integrated with refresh mechanism in `StatusXPRefresh` extension
- Located: `lib/state/statusxp_providers.dart`

### 4. UI Implementation
- Created `NewDashboardScreen` with your exact mockup design
- StatusXP circle: Neon Purple (#B026FF) - 220x220px
- PSN circle: PlayStation Blue (#00A8E1) - 110x110px
- Xbox circle: Xbox Green (#107C10) - 110x110px  
- Steam circle: Steam Blue (#66C0F4) - 110x110px
- Username header with platform indicator badge
- Quick Actions section with glass-style buttons
- Located: `lib/ui/screens/new_dashboard_screen.dart`

### 5. Routing
- New dashboard now at root path: `/`
- Legacy dashboard moved to: `/dashboard-legacy`
- Located: `lib/ui/navigation/app_router.dart`

### 6. Database Migration
- Migration file: `supabase/migrations/014_add_display_preferences.sql`
- Manual run file: `run_display_preferences_migration.sql`
- Adds 3 columns to `user_profiles`:
  - `preferred_display_platform` (psn/steam/xbox) - default 'psn'
  - `steam_display_name` (text)
  - `xbox_gamertag` (text)

## 🔧 Setup Required

### 1. Run Database Migration

Open Supabase SQL Editor and run:
```sql
-- From run_display_preferences_migration.sql
ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS preferred_display_platform text DEFAULT 'psn' 
  CHECK (preferred_display_platform IN ('psn', 'steam', 'xbox'));

ALTER TABLE user_profiles
ADD COLUMN IF NOT EXISTS steam_display_name text,
ADD COLUMN IF NOT EXISTS xbox_gamertag text;
```

### 2. Update StatusXP Base Value

The migration `013_statusxp_scoring.sql` currently has `base_value := 100`.
You need to update it to `base_value := 10` by running:

```sql
CREATE OR REPLACE FUNCTION get_achievement_statusxp(
  platform_param text,
  trophy_type_param text,
  rarity_percent numeric
)
RETURNS integer AS $$
DECLARE
  base_value integer := 10;  -- Changed from 100
  multiplier numeric;
BEGIN
  IF platform_param = 'psn' AND trophy_type_param = 'platinum' THEN
    RETURN 0;
  END IF;
  multiplier := get_rarity_multiplier(rarity_percent);
  RETURN (base_value * multiplier)::integer;
END;
$$ LANGUAGE plpgsql IMMUTABLE;
```

### 3. Test the App

```powershell
cd d:\Dev\statusxp
flutter run
```

The new dashboard should load automatically at the root path.

## 📊 Data Flow

```
User Opens App
    ↓
NewDashboardScreen loads
    ↓
dashboardStatsProvider fetches data
    ↓
SupabaseDashboardRepository queries:
    - user_statusxp_summary (total StatusXP)
    - user_achievements (per-platform counts)
    - user_games (per-platform game counts)
    - user_profiles (display preferences)
    - psn_profiles (PSN username, avatar, PS+ status)
    ↓
Returns DashboardStats model
    ↓
UI renders 4 circles + quick actions
```

## 🎨 UI Breakdown

### Circle Sizes
- **StatusXP**: 220x220px (neon purple #B026FF)
- **PSN**: 110x110px (PS blue #00A8E1)
- **Xbox**: 110x110px (Xbox green #107C10)
- **Steam**: 110x110px (Steam blue #66C0F4)

### Platform Circle Data
Each shows:
1. **Top line**: Label (e.g., "Platinums", "Xbox Achievs")
2. **Large number**: Main stat (platinums or achievement count)
3. **Small text**: Game count
4. **Below circle**: AVG/GAME box with calculated average

### Quick Actions
- View Games → `/games`
- Status Poster → `/poster`
- Leaderboards → Coming soon message

## 🔄 User Preferences

Users can select which platform name to display in settings:
- PSN Online ID (from `psn_profiles.psn_online_id`)
- Steam Display Name (from `user_profiles.steam_display_name`)
- Xbox Gamertag (from `user_profiles.xbox_gamertag`)

This preference is stored in `user_profiles.preferred_display_platform`.

## 🧪 Testing Checklist

- [ ] Run database migration
- [ ] Update StatusXP base value to 10
- [ ] Launch app and verify new dashboard loads
- [ ] Check all 4 stat circles display correct data
- [ ] Verify username and platform badge appear correctly
- [ ] Test quick action buttons navigate properly
- [ ] Test pull-to-refresh functionality
- [ ] Verify StatusXP number formatting (53.6K vs 53,560)

## 📝 Next Steps

1. **Settings Screen**: Add UI to change `preferred_display_platform`
2. **Platform Data Sync**: Ensure Steam/Xbox usernames populate during sync
3. **Leaderboards**: Implement leaderboard feature (referenced in Quick Actions)
4. **Color Customization**: Allow users to customize StatusXP circle color (optional)
5. **Remove Legacy Dashboard**: Once testing is complete, remove old dashboard

## 🎯 Current Score Display

Based on your test data:
- **StatusXP**: 53,607 (displays as "53.6K")
- **PSN**: 170 platinums, 3,960 achievements, 366 games (25 avg/game)
- **Xbox**: 573 achievements, 25 games (23 avg/game)
- **Steam**: 235 achievements, 35 games (7 avg/game)

All calculations are automatic and update whenever achievements are synced!
