# Sync Service Code Locations - Detailed Audit

**Generated:** 2025-01-21  
**Purpose:** Exact code locations for all Supabase database writes in sync services

---

## Invocation Architecture

### Railway Service (Production)
- **Host:** `https://statusxp-production.up.railway.app`
- **Entry Point:** `sync-service/index.js` (Express server)
- **Port:** 3000 (or `process.env.PORT`)
- **Invocation:** HTTP POST endpoints (no queue, no cron)

### HTTP Endpoints

| Endpoint | Handler | Line in index.js |
|----------|---------|------------------|
| `POST /sync/psn` | `syncPSNAchievements()` from `psn-sync.js` | 167 |
| `POST /sync/xbox` | `syncXboxAchievements()` from `xbox-sync.js` | 117 |
| `POST /sync/steam` | `syncSteamAchievements()` from `steam-sync.js` | 217 |

### Invocation Flow

```
Edge Function (Supabase)
    ↓ (authenticates user, gets tokens)
    ↓ HTTP POST to Railway
Railway Service (Express)
    ↓ (immediate 200 response)
    ↓ (async background job)
Sync Service Function
    ↓ (API calls, data processing)
Supabase Database Writes
    ↓ (using SERVICE ROLE KEY)
Complete
```

**Key Characteristics:**
- ✅ Responds immediately with 200 to prevent Edge Function timeout
- ✅ Runs sync in background async IIFE
- ✅ No timeout limits (can run for hours if needed)
- ✅ Manual GC calls after completion
- ✅ Protected by `SYNC_SERVICE_SECRET` bearer token

---

## Supabase Client Configuration

### All Three Services Use Service Role

```javascript
// PSN: Line 6-9
// Xbox: Line 3-6
// Steam: Line 4-7
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY  // ← SERVICE ROLE, not user token
);
```

**Why Service Role?**
- Bypasses RLS (Row Level Security) policies
- Can write to any user's data
- Required for batch operations
- Must validate `userId` parameter manually

**Security:**
- Railway validates `userId` against Edge Function auth
- Edge Functions verify JWT before calling Railway
- Railway protected by `SYNC_SERVICE_SECRET` bearer token

---

## PSN Sync Service

### Entry Point
- **File:** `sync-service/psn-sync.js`
- **Function:** `syncPSNAchievements(userId, accountId, accessToken, refreshToken, syncLogId, options)`
- **Line:** 60-67
- **Total Lines:** 961

### Database Writes

#### A) `games` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 391 | `.select()` | `SELECT` | N/A (read) |
| 415 | `.select()` | `SELECT` | N/A (read) |
| 430 | `.update()` | `UPDATE games SET cover_url = ... WHERE platform_id = ? AND platform_game_id = ?` | ❌ No (composite PK) |
| 444 | `.insert()` | `INSERT INTO games (platform_id, platform_game_id, ...) VALUES (...)` | ⚠️ **YES - see details below** |

**Line 444 Details:**
```javascript
const { data: newGame, error: insertError } = await supabase
  .from('games')
  .insert({
    platform_id: platformId,
    platform_game_id: title.npCommunicationId,  // PSN NPWR ID
    name: trimmedTitle,
    cover_url: title.trophyTitleIconUrl,
    // ...
  })
  .select()
  .single();
```

**Duplicate Risk:** 🟡 MEDIUM
- Uses `.insert()` without `.upsert()`
- Has duplicate prevention check at line 391 (reads first)
- Race condition possible if same game synced by multiple users simultaneously
- **Primary Key:** `(platform_id, platform_game_id)` prevents database-level duplicates
- **Outcome:** INSERT will fail with PK violation if duplicate

---

#### B) `achievements` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 514 | `.select()` | `SELECT` | N/A (read) |
| 750 | `.select()` | `SELECT` | N/A (read) |
| 761 | `.update()` | `UPDATE achievements SET ... WHERE platform_id = ? AND platform_game_id = ? AND platform_achievement_id = ?` | ❌ No |
| 772 | `.insert()` | `INSERT INTO achievements (...) VALUES (...)` | ⚠️ **YES - see details below** |

**Line 761 Details (UPDATE):**
```javascript
const { data } = await supabase
  .from('achievements')
  .update(achievementData)
  .eq('platform_id', platformId)
  .eq('platform_game_id', gameTitle.platform_game_id)
  .eq('platform_achievement_id', trophyMeta.trophyId.toString())
  .select()
  .single();
```

**Line 772 Details (INSERT):**
```javascript
const { data } = await supabase
  .from('achievements')
  .insert(achievementData)
  .select()
  .single();
```

**Duplicate Risk:** 🟡 MEDIUM
- Uses check-then-insert pattern (line 750 SELECT, then 772 INSERT)
- Race condition window between SELECT and INSERT
- **Primary Key:** `(platform_id, platform_game_id, platform_achievement_id)` prevents DB duplicates
- **Outcome:** INSERT will fail with PK violation if duplicate

---

#### C) `user_achievements` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 521 | `.select()` | `SELECT` | N/A (read in duplicate check) |
| 785 | `.upsert()` | `INSERT ... ON CONFLICT (user_id, platform_id, platform_game_id, platform_achievement_id) DO UPDATE SET ...` | ✅ No (upsert) |

**Line 785 Details:**
```javascript
await supabase
  .from('user_achievements')
  .upsert(
    {
      user_id: userId,
      platform_id: platformId,
      platform_game_id: gameTitle.platform_game_id,
      platform_achievement_id: achievementRecord.platform_achievement_id,
      earned_at: userTrophy.earnedDateTime,
    },
    {
      onConflict: 'user_id,platform_id,platform_game_id,platform_achievement_id',
    }
  );
```

**Duplicate Risk:** ✅ NONE
- Uses `.upsert()` with explicit `onConflict` specification
- Safe for concurrent execution

---

#### D) `user_progress` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 223 | `.select()` | `SELECT` (check if user has existing games) | N/A (read) |
| 266 | `.select()` | `SELECT` (load all user games for diff) | N/A (read) |
| 625 | `.upsert()` | `INSERT ... ON CONFLICT (user_id, platform_id, platform_game_id) DO UPDATE SET ...` | ✅ No (upsert) |
| 806 | `.update()` | `UPDATE user_progress SET last_achievement_earned_at = ... WHERE user_id = ? AND platform_id = ? AND platform_game_id = ?` | ✅ No (composite WHERE) |
| 836 | `.select()` | `SELECT` (error handler reads metadata) | N/A (read) |
| 844 | `.update()` | `UPDATE user_progress SET metadata = ... WHERE user_id = ? AND platform_id = ? AND platform_game_id = ?` | ✅ No (composite WHERE) |

**Line 625 Details (Main Write):**
```javascript
const { error: upsertError } = await supabase
  .from('user_progress')
  .upsert(userGameData, { onConflict: 'user_id,platform_id,platform_game_id' });
```

**Duplicate Risk:** ✅ NONE
- Uses `.upsert()` with proper conflict resolution
- UPDATE operations use composite WHERE (line 806, 844)

---

## Xbox Sync Service

### Entry Point
- **File:** `sync-service/xbox-sync.js`
- **Function:** `syncXboxAchievements(userId, xuid, userHash, accessToken, refreshToken, syncLogId, options)`
- **Line:** 127-134
- **Total Lines:** 1195

### Database Writes

#### A) `games` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 550 | `.select()` | `SELECT` (duplicate check) | N/A (read) |
| 566 | `.select()` | `SELECT` (find existing game) | N/A (read) |
| 582 | `.update()` | `UPDATE games SET cover_url = ... WHERE platform_id = ? AND platform_game_id = ?` | ❌ No |
| 596 | `.insert()` | `INSERT INTO games (platform_id, platform_game_id, ...) VALUES (...)` | ⚠️ **YES - see details below** |
| 1035 | `.update()` | `UPDATE games SET ... WHERE platform_id = ? AND platform_game_id = ?` (error handler) | ❌ No |

**Line 596 Details:**
```javascript
const { data: newGame, error: insertError } = await supabase
  .from('games')
  .insert({
    platform_id: platformId,
    platform_game_id: title.titleId,  // Xbox titleId
    name: trimmedName,
    cover_url: title.displayImage,
    // ...
  })
  .select()
  .single();
```

**Duplicate Risk:** 🟡 MEDIUM
- Same pattern as PSN (check-then-insert)
- Race condition possible
- **Primary Key:** `(platform_id, platform_game_id)` prevents DB duplicates

---

#### B) `achievements` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 647 | `.select()` | `SELECT` (count check) | N/A (read) |
| 732 | `.select()` | `SELECT` (find existing achievement) | N/A (read) |
| 748 | `.select()` | `SELECT` (check for proxied icon) | N/A (read) |
| 910 | `.select()` | `SELECT` (find existing achievement) | N/A (read) |
| 921 | `.update()` | `UPDATE achievements SET ... WHERE platform_id = ? AND platform_game_id = ? AND platform_achievement_id = ?` | ❌ No |
| 932 | `.insert()` | `INSERT INTO achievements (...) VALUES (...)` | ⚠️ **YES** |
| 1085 | `.update()` | `UPDATE achievements SET ... WHERE platform_id = ? AND platform_game_id = ? AND platform_achievement_id = ?` (error handler) | ❌ No |

**Line 921 & 932 Details:**
```javascript
if (existing) {
  // Update existing (line 921)
  const { data } = await supabase
    .from('achievements')
    .update(achievementData)
    .eq('platform_id', platformId)
    .eq('platform_game_id', gameTitle.platform_game_id)
    .eq('platform_achievement_id', achievement.id)
    .select()
    .single();
} else {
  // Insert new (line 932)
  const { data } = await supabase
    .from('achievements')
    .insert(achievementData)
    .select()
    .single();
}
```

**Duplicate Risk:** 🟡 MEDIUM
- Same check-then-insert pattern
- Race condition window
- **Primary Key:** `(platform_id, platform_game_id, platform_achievement_id)` prevents DB duplicates

---

#### C) `user_achievements` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 654 | `.select()` | `SELECT` (count check) | N/A (read) |
| 944 | `.upsert()` | `INSERT ... ON CONFLICT (...) DO UPDATE SET ...` | ✅ No (upsert) |
| 1106 | `.upsert()` | `INSERT ... ON CONFLICT (...) DO UPDATE SET ...` (error handler retry) | ✅ No (upsert) |

**Line 944 Details:**
```javascript
await supabase
  .from('user_achievements')
  .upsert({
    user_id: userId,
    platform_id: platformId,
    platform_game_id: gameTitle.platform_game_id,
    platform_achievement_id: achievementRecord.platform_achievement_id,
    earned_at: achievement.progression?.timeUnlocked,
  }, {
    onConflict: 'user_id,platform_id,platform_game_id,platform_achievement_id',
  });
```

**Duplicate Risk:** ✅ NONE
- Uses `.upsert()` correctly

---

#### D) `user_progress` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 438 | `.select()` | `SELECT` (load all user games) | N/A (read) |
| 823 | `.upsert()` | `INSERT ... ON CONFLICT (user_id, platform_id, platform_game_id) DO UPDATE SET ...` | ✅ No (upsert) |
| 962 | `.update()` | `UPDATE user_progress SET last_achievement_earned_at = ... WHERE ...` | ✅ No |
| 991 | `.select()` | `SELECT` (error handler) | N/A (read) |
| 999 | `.update()` | `UPDATE user_progress SET metadata = ... WHERE ...` (error handler) | ✅ No |

**Line 823 Details:**
```javascript
await supabase
  .from('user_progress')
  .upsert({
    user_id: userId,
    platform_id: platformId,
    platform_game_id: gameTitle.platform_game_id,
    // ... other fields
  }, {
    onConflict: 'user_id,platform_id,platform_game_id',
  });
```

**Duplicate Risk:** ✅ NONE
- Uses `.upsert()` correctly
- UPDATE operations safe (composite WHERE)

---

## Steam Sync Service

### Entry Point
- **File:** `sync-service/steam-sync.js`
- **Function:** `syncSteamAchievements(userId, steamId, apiKey, syncLogId, options)`
- **Line:** 71
- **Total Lines:** 734

### Database Writes

#### A) `games` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 356 | `.select()` | `SELECT` (duplicate prevention check) | N/A (read) |
| 371 | `.select()` | `SELECT` (find existing game) | N/A (read) |
| 381 | `.update()` | `UPDATE games SET cover_url = ... WHERE platform_id = ? AND platform_game_id = ?` | ❌ No |
| 396 | `.insert()` | `INSERT INTO games (platform_id, platform_game_id, ...) VALUES (...)` | ⚠️ **YES** |

**Line 396 Details:**
```javascript
const { data: newGame, error: insertError } = await supabase
  .from('games')
  .insert({
    platform_id: platformId,
    platform_game_id: game.appid.toString(),  // Steam appid
    name: trimmedName,
    cover_url: `https://cdn.cloudflare.steamstatic.com/steam/apps/${game.appid}/library_600x900.jpg`,
    // ...
  })
  .select()
  .single();
```

**Duplicate Risk:** 🟡 MEDIUM
- Same check-then-insert pattern
- **Primary Key:** `(platform_id, platform_game_id)` prevents DB duplicates

---

#### B) `achievements` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 593 | `.upsert()` | `INSERT ... ON CONFLICT (platform_id, platform_game_id, platform_achievement_id) DO UPDATE SET ...` | ✅ No (upsert) |

**Line 593 Details:**
```javascript
const { data: achievementRecord, error: achError } = await supabase
  .from('achievements')
  .upsert(achievementData, {
    onConflict: 'platform_id,platform_game_id,platform_achievement_id',
  })
  .select()
  .single();
```

**Duplicate Risk:** ✅ NONE
- Uses `.upsert()` correctly
- **Note:** Steam is the ONLY service that uses `.upsert()` for achievements

---

#### C) `user_achievements` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 442 | `.select()` | `SELECT` (count check) | N/A (read) |
| 616 | `.upsert()` | `INSERT ... ON CONFLICT (user_id, platform_id, platform_game_id, platform_achievement_id) DO UPDATE SET ...` | ✅ No (upsert) |

**Line 616 Details:**
```javascript
await supabase
  .from('user_achievements')
  .upsert({
    user_id: userId,
    platform_id: platformId,
    platform_game_id: gameTitle.platform_game_id,
    platform_achievement_id: achievement.name,  // Steam uses name as ID
    earned_at: new Date(playerAchievement.unlocktime * 1000).toISOString(),
  }, {
    onConflict: 'user_id,platform_id,platform_game_id,platform_achievement_id',
  });
```

**Duplicate Risk:** ✅ NONE
- Uses `.upsert()` correctly

---

#### D) `user_progress` Table

| Line | Operation | SQL Equivalent | Can Create Duplicates? |
|------|-----------|----------------|------------------------|
| 201 | `.select()` | `SELECT` (load all user games) | N/A (read) |
| 507 | `.upsert()` | `INSERT ... ON CONFLICT (user_id, platform_id, platform_game_id) DO UPDATE SET ...` | ✅ No (upsert) |
| 650 | `.select()` | `SELECT` (error handler) | N/A (read) |
| 658 | `.update()` | `UPDATE user_progress SET metadata = ... WHERE ...` (error handler) | ✅ No |

**Line 507 Details:**
```javascript
await supabase
  .from('user_progress')
  .upsert({
    user_id: userId,
    platform_id: platformId,
    platform_game_id: gameTitle.platform_game_id,
    total_achievements: achievements.length,
    achievements_earned: unlockedCount,
    // ... other fields
  }, {
    onConflict: 'user_id,platform_id,platform_game_id',
  });
```

**Duplicate Risk:** ✅ NONE
- Uses `.upsert()` correctly

---

## Summary: Duplicate Risk Analysis

### Critical Findings

#### 1. Games Table - Potential Race Conditions

**All Three Services Use Check-Then-Insert Pattern:**

| Service | Check Line | Insert Line | Race Window |
|---------|------------|-------------|-------------|
| PSN | 391, 415 | 444 | ~50ms typical |
| Xbox | 550, 566 | 596 | ~50ms typical |
| Steam | 356, 371 | 396 | ~50ms typical |

**Risk Assessment:** 🟡 MEDIUM
- **Scenario:** Two users sync the same game simultaneously
- **Protection:** Primary key `(platform_id, platform_game_id)` prevents duplicates at DB level
- **Outcome:** Second INSERT fails with `duplicate key value violates unique constraint`
- **Impact:** Sync fails for second user, requires retry
- **Frequency:** Rare (requires exact timing collision)

**Recommendation:**
```javascript
// REPLACE INSERT with UPSERT for games table
// Current (all services):
const { data: newGame, error: insertError } = await supabase
  .from('games')
  .insert({ platform_id, platform_game_id, ... })
  .select()
  .single();

// Recommended:
const { data: newGame, error: upsertError } = await supabase
  .from('games')
  .upsert({ platform_id, platform_game_id, ... }, {
    onConflict: 'platform_id,platform_game_id',
    ignoreDuplicates: false,  // Update if exists
  })
  .select()
  .single();
```

---

#### 2. Achievements Table - Same Pattern

**PSN & Xbox Use Check-Then-Insert:**

| Service | Pattern | Lines |
|---------|---------|-------|
| PSN | SELECT → INSERT/UPDATE | 750, 761, 772 |
| Xbox | SELECT → INSERT/UPDATE | 910, 921, 932 |
| Steam | UPSERT | 593 ✅ |

**Risk Assessment:** 🟡 MEDIUM (PSN, Xbox only)
- Same race condition as games table
- **Primary Key:** `(platform_id, platform_game_id, platform_achievement_id)`
- **Outcome:** Duplicate INSERT fails, sync needs retry

**Best Practice:** Steam's approach (`.upsert()`) is correct

**Recommendation:**
```javascript
// REPLACE CHECK-THEN-INSERT with UPSERT (PSN & Xbox)
// Steam already does this correctly at line 593

const { data: achievementRecord, error: achError } = await supabase
  .from('achievements')
  .upsert(achievementData, {
    onConflict: 'platform_id,platform_game_id,platform_achievement_id',
  })
  .select()
  .single();
```

---

#### 3. User Data Tables - Safe ✅

**Both `user_achievements` and `user_progress` use `.upsert()` correctly:**

| Table | All Services Use | Risk |
|-------|-----------------|------|
| `user_achievements` | `.upsert()` with `onConflict` | ✅ NONE |
| `user_progress` | `.upsert()` with `onConflict` | ✅ NONE |

---

## Questions Answered

### 1) Which service runs in production and how is it invoked?

**Service:** Railway-hosted Express server  
**Location:** `sync-service/index.js`  
**Invocation:** HTTP POST endpoints (not queue, not cron)

| Endpoint | Trigger |
|----------|---------|
| `POST https://statusxp-production.up.railway.app/sync/psn` | Edge Function: `supabase/functions/psn-start-sync` |
| `POST https://statusxp-production.up.railway.app/sync/xbox` | Edge Function: `supabase/functions/xbox-start-sync` |
| `POST https://statusxp-production.up.railway.app/sync/steam` | Edge Function: `supabase/functions/steam-start-sync` |

**Flow:**
1. User triggers sync from Flutter app
2. App calls Edge Function
3. Edge Function authenticates user, creates sync log
4. Edge Function calls Railway HTTP endpoint
5. Railway responds 200 immediately
6. Railway runs sync in background async
7. Sync writes to Supabase using service role key

---

### 2) Which Supabase client is used?

**All Services Use:** Service Role Key

```javascript
// psn-sync.js line 6-9
// xbox-sync.js line 3-6  
// steam-sync.js line 4-7
const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY  // ← Bypasses RLS
);
```

**Why Service Role?**
- Needs to write to any user's data (batch sync)
- Bypasses Row Level Security (RLS)
- Can't use user tokens (sync runs after user disconnects)
- Requires manual validation of `userId` parameter

**Security Model:**
- Edge Function validates user JWT
- Edge Function passes validated `userId` to Railway
- Railway trusts `userId` from Edge Function
- Railway protected by `SYNC_SERVICE_SECRET` bearer token

---

### 3) Which INSERT calls can create duplicates?

**Summary Table:**

| Table | PSN | Xbox | Steam | Risk |
|-------|-----|------|-------|------|
| `games` | Line 444 (.insert) | Line 596 (.insert) | Line 396 (.insert) | 🟡 MEDIUM |
| `achievements` | Line 772 (.insert) | Line 932 (.insert) | Line 593 (.upsert) ✅ | 🟡 MEDIUM (PSN/Xbox) |
| `user_achievements` | Line 785 (.upsert) ✅ | Line 944 (.upsert) ✅ | Line 616 (.upsert) ✅ | ✅ NONE |
| `user_progress` | Line 625 (.upsert) ✅ | Line 823 (.upsert) ✅ | Line 507 (.upsert) ✅ | ✅ NONE |

**Total Risky INSERTs:** 8 locations
- PSN: 2 (games, achievements)
- Xbox: 2 (games, achievements)
- Steam: 1 (games only - achievements uses upsert)

**Database Protection:**
- Primary keys prevent actual duplicates
- INSERT fails with constraint violation
- Sync must be retried

**Recommendation:** Replace all `.insert()` with `.upsert()` for `games` and `achievements` tables.

---

## Additional Observations

### Memory Management
- All services call `global.gc()` after completion
- PSN has explicit memory logging (`logMemory()`)
- Xbox has lowest batch size (5) to reduce memory
- Steam has aggressive garbage collection

### Error Handling
- All services update sync logs on error
- Failed games marked with `metadata.sync_failed = true`
- Sync continues even if individual games fail
- Profiles table updated with error status

### Icon Proxying
- All services upload achievement icons to Supabase Storage
- Fallback to original URL if upload fails
- Uses `game-assets` bucket with CDN
- Prevents external hotlinking issues

### Platform Detection
- PSN uses IGDB validator for platform classification
- Xbox uses API platform hints + IGDB fallback
- Steam hardcoded to platform_id = 4
- Multi-platform games tracked separately per platform

---

## Next Steps

1. ✅ Review this detailed audit
2. ⏳ Decide on handling duplicate INSERTs (migrate to upsert vs. accept retry behavior)
3. ⏳ Consider whether sync services need profile_id migration (see SYNC_SERVICE_AUDIT_REPORT.md)
4. ⏳ Test edge cases for race conditions
5. ⏳ Deploy application code changes

---

**Document Status:** Complete  
**Reviewed:** Pending  
**Last Updated:** 2025-01-21
