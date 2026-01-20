# StatusXP Database Redesign

## Problems with Current Structure

### 1. Duplicate Data
- Same game appears multiple times with different `game_title_id`
- Example: "Warframe" exists as IDs 2495 and 418
- Causes: Incorrect totals, wasted storage, complex deduplication queries

### 2. Poor Primary Keys
- Using auto-increment IDs instead of platform-specific identifiers
- `xbox_title_id`, `psn_npwr_id`, `steam_app_id` are nullable
- Can't prevent duplicates at database level

### 3. Expensive Queries
- Multiple JOINs required for simple queries
- No proper indexes on foreign keys
- GROUP BY operations on every request
- Disk I/O budget exceeded

### 4. No Unique Constraints
- `user_games` allows duplicate (user_id, game, platform) entries
- `game_titles` allows duplicate game names
- Database can't enforce data integrity

## New Schema Design Principles

### Core Principles
1. **Platform-specific IDs are primary keys** (not nullable)
2. **Unique constraints prevent duplicates** at insert time
3. **Indexes on all foreign keys** for fast JOINs
4. **Denormalize read-heavy data** (cache tables)
5. **Partition large tables** by platform for performance

---

## New Table Structure

### Table: `platforms` (Keep - No Changes)
```sql
id            BIGSERIAL PRIMARY KEY
code          TEXT UNIQUE NOT NULL  -- 'psn', 'xbox', 'steam'
name          TEXT NOT NULL
```

### Table: `games` (New - Replaces `game_titles`)
**Purpose:** Single source of truth for all games across all platforms

```sql
-- Composite primary key: platform + platform_game_id
platform_id         BIGINT NOT NULL REFERENCES platforms(id)
platform_game_id    TEXT NOT NULL           -- xbox_title_id, psn_npwr_id, or steam_app_id
name                TEXT NOT NULL
cover_url           TEXT
proxied_cover_url   TEXT
metadata            JSONB
created_at          TIMESTAMPTZ DEFAULT NOW()
updated_at          TIMESTAMPTZ DEFAULT NOW()

PRIMARY KEY (platform_id, platform_game_id)
CREATE INDEX idx_games_name ON games(name)
CREATE INDEX idx_games_platform ON games(platform_id)
```

**Key Changes:**
- No auto-increment ID
- Platform-specific ID is part of primary key → **impossible to create duplicates**
- Each game appears once per platform
- Fast lookups by platform_game_id

### Table: `user_progress` (New - Replaces `user_games`)
**Purpose:** Track user progress on games

```sql
user_id                 UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
platform_id             BIGINT NOT NULL
platform_game_id        TEXT NOT NULL
-- PSN fields
total_trophies          INT
earned_trophies         INT
bronze_trophies         INT
silver_trophies         INT
gold_trophies           INT
platinum_trophies       INT
-- Xbox fields
xbox_total_achievements INT
xbox_earned_achievements INT
xbox_current_gamerscore INT
xbox_max_gamerscore     INT
-- Steam fields
steam_total_achievements INT
steam_earned_achievements INT
-- Common fields
completion_percent      NUMERIC(5,2)
last_played_at          TIMESTAMPTZ
created_at              TIMESTAMPTZ DEFAULT NOW()
updated_at              TIMESTAMPTZ DEFAULT NOW()

PRIMARY KEY (user_id, platform_id, platform_game_id)
FOREIGN KEY (platform_id, platform_game_id) REFERENCES games(platform_id, platform_game_id)

CREATE INDEX idx_user_progress_user ON user_progress(user_id)
CREATE INDEX idx_user_progress_platform ON user_progress(platform_id)
CREATE INDEX idx_user_progress_updated ON user_progress(updated_at DESC)
```

**Key Changes:**
- Composite primary key → **duplicate entries impossible**
- Foreign key to `games` table ensures game exists
- All progress data in one place per user+game+platform combo
- Platform-specific columns clearly labeled

### Table: `achievements` (Update - Add composite key)
**Purpose:** Master list of all achievements

```sql
-- New structure
platform_id             BIGINT NOT NULL
platform_game_id        TEXT NOT NULL
platform_achievement_id TEXT NOT NULL           -- Unique ID from platform API
name                    TEXT NOT NULL
description             TEXT
icon_url                TEXT
proxied_icon_url        TEXT
rarity_percent          NUMERIC(5,2)
points                  INT                     -- Gamerscore (Xbox) or trophy type value (PSN)
trophy_type             TEXT                    -- 'bronze', 'silver', 'gold', 'platinum' for PSN
is_hidden               BOOLEAN DEFAULT FALSE
display_order           INT
metadata                JSONB
created_at              TIMESTAMPTZ DEFAULT NOW()
updated_at              TIMESTAMPTZ DEFAULT NOW()

PRIMARY KEY (platform_id, platform_game_id, platform_achievement_id)
FOREIGN KEY (platform_id, platform_game_id) REFERENCES games(platform_id, platform_game_id)

CREATE INDEX idx_achievements_game ON achievements(platform_id, platform_game_id)
CREATE INDEX idx_achievements_rarity ON achievements(rarity_percent)
```

**Key Changes:**
- Composite primary key prevents duplicate achievements
- Foreign key ensures achievement belongs to valid game
- No auto-increment ID needed

### Table: `user_achievements` (Update - Use composite keys)
**Purpose:** Track which achievements users have unlocked

```sql
user_id                     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
platform_id                 BIGINT NOT NULL
platform_game_id            TEXT NOT NULL
platform_achievement_id     TEXT NOT NULL
earned_at                   TIMESTAMPTZ NOT NULL
created_at                  TIMESTAMPTZ DEFAULT NOW()

PRIMARY KEY (user_id, platform_id, platform_game_id, platform_achievement_id)
FOREIGN KEY (platform_id, platform_game_id, platform_achievement_id) 
    REFERENCES achievements(platform_id, platform_game_id, platform_achievement_id)

CREATE INDEX idx_user_achievements_user ON user_achievements(user_id, earned_at DESC)
CREATE INDEX idx_user_achievements_game ON user_achievements(platform_id, platform_game_id)
CREATE INDEX idx_user_achievements_earned ON user_achievements(earned_at DESC)
```

**Key Changes:**
- Composite primary key → **can't earn same achievement twice**
- Foreign key ensures achievement exists
- Fast queries for user's achievements
- Fast queries for achievement earners

---

## Cache Tables (Keep but Simplify)

### `psn_leaderboard_cache`
```sql
user_id         UUID PRIMARY KEY
display_name    TEXT NOT NULL
avatar_url      TEXT
platinum_count  BIGINT NOT NULL DEFAULT 0
total_trophies  BIGINT NOT NULL DEFAULT 0
total_games     BIGINT NOT NULL DEFAULT 0
updated_at      TIMESTAMPTZ DEFAULT NOW()

CREATE INDEX idx_psn_leaderboard_platinum ON psn_leaderboard_cache(platinum_count DESC)
CREATE INDEX idx_psn_leaderboard_trophies ON psn_leaderboard_cache(total_trophies DESC)
```

### `xbox_leaderboard_cache`
```sql
user_id             UUID PRIMARY KEY
display_name        TEXT NOT NULL
avatar_url          TEXT
gamerscore          BIGINT NOT NULL DEFAULT 0
achievement_count   BIGINT NOT NULL DEFAULT 0
total_games         BIGINT NOT NULL DEFAULT 0
updated_at          TIMESTAMPTZ DEFAULT NOW()

CREATE INDEX idx_xbox_leaderboard_gamerscore ON xbox_leaderboard_cache(gamerscore DESC)
CREATE INDEX idx_xbox_leaderboard_achievements ON xbox_leaderboard_cache(achievement_count DESC)
```

### `steam_leaderboard_cache`
```sql
user_id             UUID PRIMARY KEY
display_name        TEXT NOT NULL
avatar_url          TEXT
achievement_count   BIGINT NOT NULL DEFAULT 0
total_games         BIGINT NOT NULL DEFAULT 0
updated_at          TIMESTAMPTZ DEFAULT NOW()

CREATE INDEX idx_steam_leaderboard_achievements ON steam_leaderboard_cache(achievement_count DESC)
```

---

## Query Performance Examples

### Before (Current Structure)
```sql
-- Get user's Xbox gamerscore (with deduplication)
SELECT SUM(max_gs) 
FROM (
  SELECT gt.name, MAX(ug.xbox_current_gamerscore) as max_gs
  FROM user_games ug
  JOIN game_titles gt ON ug.game_title_id = gt.id
  JOIN platforms pl ON ug.platform_id = pl.id
  WHERE ug.user_id = $1 AND pl.code IN ('XBOXONE', 'XBOX360', 'XBOXSERIESX')
  GROUP BY gt.name
) deduped;
-- Reads: 500+ rows, 2 JOINs, GROUP BY, nested query
```

### After (New Structure)
```sql
-- Get user's Xbox gamerscore
SELECT SUM(xbox_current_gamerscore)
FROM user_progress
WHERE user_id = $1 AND platform_id = (SELECT id FROM platforms WHERE code = 'xbox');
-- Reads: User's games only (~50-500 rows), 1 table, indexed lookup
```

**Speed improvement: 10-50x faster**

---

## Migration Strategy

### Phase 1: Add Critical Indexes (Today)
- Stop disk I/O bleeding on current tables
- Add indexes on foreign keys
- No breaking changes

### Phase 2: Create New Tables (This Week)
- Create `games`, `user_progress` tables alongside old ones
- No app changes yet
- Test structure thoroughly

### Phase 3: Migrate Data (Next Week)
- Write migration scripts with validation
- Migrate games → deduplicate during migration
- Migrate user_games → user_progress
- Migrate achievements → update references
- Keep old tables as backup

### Phase 4: Update Application Code
- Update Dart models
- Update repository queries
- Use new table structure
- Deploy incrementally

### Phase 5: Cleanup (When Stable)
- Drop old tables
- Clean up temp migration scripts
- Document new structure

---

## Benefits of New Structure

### ✅ Performance
- 10-50x faster queries (fewer JOINs, better indexes)
- Disk I/O reduced by ~70% (no duplicate data)
- Query timeout issues eliminated

### ✅ Data Integrity
- Duplicates impossible (database enforces uniqueness)
- Foreign keys prevent orphaned data
- Atomic operations (no race conditions)

### ✅ Scalability
- Can partition by platform_id if needed
- Indexes support millions of rows
- Cache tables for expensive aggregations

### ✅ Maintainability
- Clear relationship between tables
- Self-documenting structure (composite keys tell the story)
- Easy to add new platforms

### ✅ Cost
- Lower disk I/O = lower Supabase costs
- Smaller database size (no duplicates)
- Faster queries = less CPU usage

---

## Next Steps

1. ✅ Review this design
2. Create Phase 1 indexes migration
3. Create Phase 2 new tables migration
4. Write data migration scripts
5. Update application code
