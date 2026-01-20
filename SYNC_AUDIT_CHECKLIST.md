# Sync Service Audit Checklist

## Critical Issues Found So Far:
1. ✅ FIXED: Xbox sync uploadExternalIcon() missing (crash)
2. ✅ FIXED: Xbox sync progress counter stuck (never incremented on error)
3. ✅ FIXED: Xbox sync filter excluded all games (gamerscore > 0 only)
4. ✅ FIXED: Xbox sync diff check used unreliable API field (totalAchievements)
5. ✅ FIXED: RLS policy blocking ALL achievement inserts (CURRENT_USER vs auth.role())
6. ✅ FIXED: PSN leaderboard counting from empty user_achievements instead of user_games
7. ✅ FIXED: Steam leaderboard excluding users with 0 achievements
8. ⚠️  UNKNOWN: Xbox leaderboard - needs audit
9. ⚠️  UNKNOWN: No sync queue - simultaneous syncs cause resource contention

## Areas to Audit:

### 1. PSN Sync (psn-sync.js)
- [ ] Does it write to user_achievements correctly with fixed RLS?
- [ ] Does it handle PSN API errors gracefully?
- [ ] Does it update leaderboard cache after sync?
- [ ] Does it handle cross-platform games (PS4/PS5 stacks)?
- [ ] Are progress counters accurate?
- [ ] Does it proxy icons correctly?
- [ ] Trophy rarity data fetched and stored?

### 2. Xbox Sync (xbox-sync.js)
- [x] uploadExternalIcon() exists
- [x] Progress counter increments on error
- [x] Filter includes games with achievements OR gamerscore
- [x] Diff check uses gamerscore not totalAchievements
- [x] Name-based lookup fallback works
- [x] xbox_title_id backfill logic works
- [ ] Does it write to user_achievements with fixed RLS?
- [ ] Does it update leaderboard cache after sync?
- [ ] Token refresh works correctly?
- [ ] Handles 401/403 errors gracefully?
- [ ] Cross-platform backward compatibility (360/One/Series)?

### 3. Steam Sync (steam-sync.js)
- [ ] Does it write to user_achievements correctly with fixed RLS?
- [ ] Does it handle Steam API rate limits?
- [ ] Does it update leaderboard cache after sync?
- [ ] Does it handle games with 0 achievements?
- [ ] Progress counter accurate?
- [ ] Icon proxying works?
- [ ] Rarity data (global achievement percentages)?

### 4. Leaderboard Cache Functions
- [x] refresh_psn_leaderboard_cache() uses user_games data
- [x] refresh_steam_leaderboard_cache() includes 0 achievement users
- [ ] refresh_xbox_leaderboard_cache() needs audit
- [ ] Are these called automatically after sync completes?
- [ ] Do they timeout with large datasets?

### 5. Database Schema Issues
- [ ] user_achievements RLS policies correct for all operations?
- [ ] Foreign key constraints working properly?
- [ ] Indexes exist for common queries?
- [ ] Do v2 tables need to be populated?
- [ ] Are there other tables with broken RLS policies?

### 6. Sync Architecture Issues
- [ ] No job queue - multiple simultaneous syncs cause problems
- [ ] Long-running HTTP requests (5-10 min) - Railway timeout?
- [ ] No sync locking mechanism - same user can trigger multiple syncs
- [ ] Memory leaks during large syncs?
- [ ] Error handling incomplete - some errors don't mark sync_failed

## Next Steps:
1. Run reset_all_users_sync.sql
2. Systematically review each sync service code
3. Test each platform sync end-to-end
4. Fix any discovered issues
5. Add sync queue before public release
