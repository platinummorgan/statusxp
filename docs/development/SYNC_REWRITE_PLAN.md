# PSN Sync Rewrite - Simple & Fast

## Current Problem
- Queries DB inside loop (2 queries × 200 games = 400 queries)
- Complex validation logic
- Slow even for unchanged games

## New Approach

### 1. Load ALL data upfront (1 query each)
```javascript
// Get all user's games once
const userGames = await supabase
  .from('user_games')
  .select('game_title_id, platform_id, earned_trophies, total_trophies, completion_percent')
  .eq('user_id', userId);

// Create lookup map
const userGamesMap = new Map();
userGames.forEach(ug => {
  userGamesMap.set(`${ug.game_title_id}_${ug.platform_id}`, ug);
});
```

### 2. Simple decision logic
```javascript
for (const apiGame of apiGames) {
  const dbGame = userGamesMap.get(`${gameId}_${platformId}`);
  
  if (!dbGame) {
    // NEW GAME - fetch all trophies
    await fetchAndInsertTrophies(apiGame);
  } else if (dbGame.earned_trophies !== apiGame.earnedTrophies) {
    // PROGRESS CHANGED - update user achievements only
    await updateEarnedTrophies(apiGame);
  } else {
    // NO CHANGE - skip
    console.log(`⏭️ Skip: ${apiGame.name}`);
  }
}
```

### 3. Performance
- Old: 400+ DB queries before starting
- New: 2 DB queries total upfront
- Lookup: O(1) hash map
- Speed: Milliseconds for unchanged games

## Implementation
1. Load user_games into Map (1 query)
2. For each API game: Map lookup
3. Only fetch trophies if new or changed
4. No field validation (trust triggers)
