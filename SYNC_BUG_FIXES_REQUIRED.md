# CRITICAL SYNC SERVICE BUGS - MUST FIX BEFORE RESYNC
## ⚠️ ALL THREE SYNC SERVICES ARE AFFECTED ⚠️

## Bug 1: platform.id undefined (ALL SYNC SERVICES)

## Bug 1: platform.id undefined (ALL SYNC SERVICES)

### PSN Sync (psn-sync.js)
**Location:** Lines 277-290, used at line 482

**Problem:**
```javascript
const { data: platform } = await supabase
  .from('platforms')
  .select('id')
  .eq('code', platformCode)
  .single();

if (!platform) {
  console.error(`❌ Platform not found...`);
  return;
}

// Later at line 482:
platform_id: platform.id,  // ← BUG: platform might be undefined if query failed!
```

### Xbox Sync (xbox-sync.js)
**Location:** Lines 337-346, used at line 553

**Problem:**
```javascript
const { data: platform} = await supabase
  .from('platforms')
  .select('id')
  .eq('code', 'XBOXONE')
  .single();

if (!platform) {
  console.error('XBOXONE platform not found in database!');
  continue;  // ← Continues loop but platform undefined
}

// Later at line 553:
platform_id: platform.id,  // ← BUG: Same issue!
```

### Steam Sync (steam-sync.js)  
**Location:** Lines 188-197, used at line 336

**Problem:**
```javascript
const { data: platform } = await supabase
  .from('platforms')
  .select('id')
  .eq('code', 'Steam')
  .single();

if (!platform) {
  console.error('Steam platform not found in database!');
  continue;
}

// Later at line 336:
platform_id: platform.id,  // ← BUG: Same issue!
```

**Why it happens in ALL services:**
- If Supabase query fails (network timeout, connection issue), `data` is undefined
- Code checks `if (!platform)` but doesn't destructure `error`
- If query fails silently, platform is undefined
- Code continues and `platform.id` resolves to `undefined`
- Database coerces undefined to NULL or wrong platform_id

**Universal Fix Pattern:**
```javascript
// Destructure BOTH data and error
const { data: platform, error: platformError } = await supabase
  .from('platforms')
  .select('id')
  .eq('code', 'PLATFORM_CODE')
  .single();

if (platformError || !platform) {
  console.error(
    `❌ Platform query failed for PLATFORM_CODE:`,
    platformError?.message || 'Platform not found'
  );
  console.error(`   Skipping game: ${gameName}`);
  return;  // or continue; for loops
}

console.log(`✅ Platform resolved: PLATFORM_CODE → ID ${platform.id}`);
```

## Bug 2: Database constraint doesn't match sync code (ALL SERVICES)

**Location:** Database schema + all sync service upserts

**Problem:**
- Database: `UNIQUE(user_id, game_title_id)` - one entry per game
- ALL sync code: Uses `platform_id` in upsert conflict clause
- Users can't own same game on multiple platforms

**PSN Code (Line 418, 509):**
```javascript
await supabase
  .from('user_games')
  .upsert(userGameData, { onConflict: 'user_id,game_title_id,platform_id' });
```

**Xbox Code (Line 575):**
```javascript
await supabase
  .from('user_games')
  .upsert(userGameData, { onConflict: 'user_id,game_title_id,platform_id' });
```

**Steam Code (Line 345):**
```javascript
await supabase
  .from('user_games')
  .upsert({...}, { onConflict: 'user_id,game_title_id,platform_id' });
```

**Actual Database Constraint:**
```sql
unique (user_id, game_title_id)  -- No platform_id!
```

**Options:**

### Option A: Change Database (Recommended)
```sql
-- Drop old constraint
ALTER TABLE user_games 
DROP CONSTRAINT user_games_user_id_game_title_id_key;

-- Add new constraint with platform_id
ALTER TABLE user_games 
ADD CONSTRAINT user_games_user_id_game_title_id_platform_id_key 
UNIQUE (user_id, game_title_id, platform_id);
```

Then sync code can stay as-is with proper multi-platform support.

### Option B: Change Sync Code
```javascript
// Only if you want to keep single-platform-per-game constraint
await supabase
  .from('user_games')
  .upsert(userGameData, { onConflict: 'user_id,game_title_id' });
  // Remove platform_id from conflict clause
```

But this means users can only track one platform per game.

## Bug 3: Platform mapping edge cases

**Location:** Line 270-275

**Problem:**
```javascript
let platformCode = 'PS5';  // Default to PS5
if (title.trophyTitlePlatform) {
  const psnPlatform = title.trophyTitlePlatform.toUpperCase();
  if (psnPlatform.includes('PS5')) platformCode = 'PS5';
  else if (psnPlatform.includes('PS4')) platformCode = 'PS4';
  // ...
}
```

PSN can return: `"PS5,PS4"` for cross-platform games. This defaults to PS5 but user might be playing on PS4.

**Better approach:**
```javascript
// Take the HIGHEST platform in the list
let platformCode = 'PS5';  // Default
if (title.trophyTitlePlatform) {
  const psnPlatform = title.trophyTitlePlatform.toUpperCase();
  // Priority: PS5 > PS4 > PS3 > VITA
  if (psnPlatform.includes('PS5')) platformCode = 'PS5';
  else if (psnPlatform.includes('PS4')) platformCode = 'PS4';
  else if (psnPlatform.includes('PS3')) platformCode = 'PS3';
  else if (psnPlatform.includes('VITA')) platformCode = 'PSVITA';
  else {
    console.warn(`⚠️  Unknown platform: ${title.trophyTitlePlatform}, defaulting to PS5`);
  }
}
console.log(`📱 Platform detected: ${title.trophyTitlePlatform} → ${platformCode}`);
```

## Recommended Fix Order

1. **FIRST:** Fix platform.id bug in ALL THREE sync services (add error handling)
   - psn-sync.js lines 277-290
   - xbox-sync.js lines 337-346  
   - steam-sync.js lines 188-197

2. **SECOND:** Decide on database constraint strategy (affects all platforms)

3. **THIRD:** Add platform detection logging (PSN only - Xbox/Steam already hardcoded)

4. **THEN:** Deploy and test with ONE user on EACH platform

5. **FINALLY:** Nuclear wipe + mass resync

## Testing Checklist

Before mass resync:
- [ ] Fixed platform.id undefined bug in psn-sync.js
- [ ] Fixed platform.id undefined bug in xbox-sync.js
- [ ] Fixed platform.id undefined bug in steam-sync.js
- [ ] Verified platform lookups succeed (PS5, PS4, PS3, PSVITA, XBOXONE, Steam)
- [ ] Decided on single vs multi-platform constraint
- [ ] Tested PSN sync with at least one user
- [ ] Tested Xbox sync with at least one user  
- [ ] Tested Steam sync with at least one user
- [ ] Verified user_games.platform_id is correct for each platform:
  - PSN games: platform_id = 1 (or PS-specific IDs)
  - Xbox games: platform_id = 2 (or Xbox-specific ID)
  - Steam games: platform_id = 3 (or Steam-specific ID)
- [ ] No more undefined/null platform_ids in any sync
