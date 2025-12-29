# Brainstorming Session - December 29, 2025

## 1. Game Discovery & Browse Feature

**Problem:** Users can only view games they've already synced. Can't preview achievements/trophies before earning them.

**Proposed Solution:**
- **Game Catalog** - Full searchable database of all games
  - Filter by platform (PS5, Xbox, Steam, etc.)
  - Sort options: popularity, difficulty, newest, completion rate
  - Show community stats ("847 users completed this")

- **Game Preview Screen**
  - Full achievement/trophy list with rarities
  - Estimated completion time/difficulty
  - Community completion percentage
  - AI guide previews (potential monetization)

- **User Comparison Features**
  - "Do I own this?" indicator
  - Wishlist functionality
  - "Track progress" button (appears after sync)

**Strategic Benefits:**
- Help users decide what to play next
- Showcase database breadth
- Drive guide purchases
- Increase community engagement
- Per-game leaderboards

**Implementation Questions:**
- Entry points: Separate "Browse Games" tab? Search from dashboard? Both?
- Database queries: Need to handle games without user_games entries
- UI: Card grid? List view? Filters sidebar?

---

## 2. Meta Achievement System Revamp

**Problem:** Current meta achievements (app accomplishments) treat all platforms equally. Users without all 3 systems see achievements they can't complete.

**Proposed Solution:**
- **Platform-Specific Achievement Categories**
  - PSN Achievements (PSN-only users)
  - Xbox Achievements (Xbox-only users)
  - Steam Achievements (Steam-only users)
  - Multi-platform Achievements (requires 2+ platforms)
  - Cross-Platform Achievements (requires all 3 platforms)

- **Smart Filtering Based on Connected Accounts**
  - Only show achievements for platforms user has connected
  - "Cross-platform" category only appears if user has 2+ platforms
  - "All Platforms" achievements only visible if user has all 3

- **Achievement Examples by Category**
  - PSN Only: "Platinum Hunter" - Earn 100 platinums
  - Xbox Only: "Gamerscore Legend" - Reach 100,000G
  - Steam Only: "Achievement Collector" - Unlock 1,000 achievements
  - Multi-platform: "Cross-Console Gamer" - Earn achievements on 2 different platforms
  - All Platforms: "Universal Gamer" - Complete a game on all 3 platforms

**Strategic Benefits:**
- Better user experience - no "locked out" achievements
- Encourages platform connection without forcing it
- Clear progression path for each user's setup
- Could incentivize adding more platforms ("You're 1 platform away from Cross-Platform achievements!")

**Implementation Questions:**
- Track which platforms user has ever connected (even if currently disconnected)?
- How to handle users who disconnect a platform after earning multi-platform achievements?
- Should there be a "View All" option to see what they're missing?
- Badge/icon system to show which category each achievement belongs to?

**Additional Notes:**
- Current meta achievements need review - some are "weird" and don't make sense
- Need to audit existing achievements for clarity and relevance
- Consider themes: milestones, rarity hunting, completion stats, social achievements

---

## 3. Flex Room - Smart Suggestions Optimization

**Problem:** "Smart Suggestions" shows the same games for every superlative (Biggest Grind, Rarest Flex, etc.) - not contextually relevant.

**Current Behavior:**
- User clicks "Biggest Grind" (or any flex slot)
- Clicks "Smart Suggestions"
- Shows generic game list (same for all categories)
- Not actually "smart" or tailored to the flex type

**Possible Solutions:**

**Option A: Make It Actually Smart**
- Biggest Grind → Sort by total play time / completion difficulty
- Rarest Flex → Sort by rarity percentage (lowest first)
- Sweatiest Platinum → Sort by platinum rarity + difficulty
- Most Time Sunk → Sort by actual hours played
- Each suggestion contextually matches what the flex represents

**Option B: Remove It**
- If logic is too complex or data isn't available
- Just show all games, let user search/filter manually
- Cleaner UX than misleading "smart" suggestions

**Option C: Hybrid Approach**
- Keep manual selection as primary
- Add "Top Recommendations" section at top
- Show 3-5 truly relevant games based on flex type
- Rest is searchable list

**Data Considerations:**
- Do we have play time data for all platforms?
- Can we calculate "grind" metrics (achievements per hour)?
- Rarity data availability per game
- Platinum difficulty ratings

**UX Questions:**
- Is the current "Smart Suggestions" button even used much?
- Would users prefer just a sorted list by default?
- Should suggestions explain WHY they're suggested? ("This game has 500+ hours average completion")

---

## Summary

**Three Priority Features for Implementation:**

1. **Game Discovery & Browse** - Let users explore games they don't own yet
2. **Meta Achievement System Revamp** - Platform-specific categories, audit existing achievements
3. **Flex Room Smart Suggestions** - Make suggestions actually contextual or remove them

**Impact Assessment:**
These three features would tremendously improve the app by:
- Opening up the database beyond just "your games"
- Creating better progression paths for different user types
- Fixing misleading/confusing UX in the Flex Room

---

## 4. Dynamic Platform Visibility System (PRIORITY)

**Vision:** The app should only show platforms the user has connected/synced. If they don't have Steam, act like Steam doesn't exist.

**Problem:** Currently showing all 3 platforms regardless of what user has connected:
- Dashboard shows 3 circles even if user only has 2 platforms (shows "0" for missing platform)
- "My Games" filters show all platforms (Steam filter visible even if no Steam account)
- Achievements show all platforms (displays "0" for platforms user doesn't have)
- Confusing and cluttered UX

**Solution - Hide Missing Platforms Completely:**

### Dashboard Changes:
- **Only show circles for connected platforms**
  - Xbox + PS only? → Show 2 circles
  - Just Steam? → Show 1 circle
  - All 3? → Show all 3 circles
- **Don't show "0" for missing platforms** - either hide or show "N/A"

### Filters Changes:
- **My Games screen** - Only show platform filters for connected platforms
  - No Steam account? → No "Steam" filter chip
  - Dynamic filter list based on user's connected platforms
  
### Achievements Changes:
- **Meta Achievements** - Only show achievements user can earn
  - No Xbox? → Hide Xbox-specific achievements
  - Only show cross-platform achievements if user has multiple platforms
  - OR show "N/A" / locked state for platforms they don't have

### Navigation Changes:
- **Platform tabs/sections** - Only visible if connected
- **Stats screens** - Hide stats for platforms they don't have

**Implementation Strategy:**

1. **Check User's Connected Platforms**
   - Query profiles table: `psn_online_id`, `xbox_gamertag`, `steam_id`
   - Create `hasPS`, `hasXbox`, `hasSteam` boolean flags
   - Store in state/provider for app-wide access

2. **Conditional Rendering Throughout App**
   - Dashboard: `if (hasPS) show PS circle`
   - Filters: Build filter list dynamically
   - Achievements: Filter by available platforms
   - Navigation: Conditionally show sections

3. **Graceful Handling**
   - First-time users (no platforms): Show onboarding prompt
   - Platform disconnected: Update UI immediately
   - Platform added: Show new sections dynamically

**Benefits:**
- Cleaner, less cluttered UI
- No confusing "0" scores for platforms user doesn't have
- Personalized experience for each user's setup
- Encourages connecting platforms without forcing it
- Reduces cognitive load

**Technical Considerations:**
- Need reliable way to check if platform is "connected" (has ID + recent sync?)
- Real-time updates when platform connected/disconnected
- Cache connected platforms list to avoid repeated queries
- Handle edge cases (platform connected but no games synced yet)

---

## 5. Meta Achievements Audit - Issues Found

**Current Problems with Existing Achievements:**

### REMOVE COMPLETELY:

1. **Fresh Flex** - Get rarest trophy in last 7 days
   - **Issue:** If you already have a 0.1% achievement, impossible to beat
   - **Verdict:** DELETE

2. **Touch Grass** - Go 7 days without earning trophy/achievement
   - **Issue:** Anti-engagement, encourages NOT using the app
   - **Verdict:** DELETE - we want usage, not absence

3. **Speedrun Finish** - Complete game in under 2 hours
   - **Issue:** Promotes shovelware, cheap completions
   - **Verdict:** DELETE - goes against quality gameplay

4. **Birthday Buff** - Earn achievement on your birthday
   - **Issue:** We don't collect birthdates
   - **Verdict:** DELETE - not feasible

5. **Profile Pimp** - Customize avatar and banner
   - **Issue:** We don't have avatar/banner customization capability
   - **Verdict:** DELETE or DEFER until feature exists

### NEEDS ADJUSTMENT:

6. **Power Session** - Earn 100 trophies/achievements within 24 hours
   - **Issue:** 100 is too high, unrealistic for most users
   - **Fix:** Reduce to 50 achievements in 24 hours

7. **So Close It Hurts** - Get to 90% completion without finishing
   - **Issue:** Impossible on PS - last trophy is platinum (auto-completes)
   - **Fix:** Make Xbox/Steam only, or change criteria

8. **Night Owl + Early Grind** - Time-based achievements
   - **Issue:** If you get Night Owl (midnight achievement), you auto-get Early Grind (morning achievement)
   - **Fix:** Check logic, may need different time windows or make mutually exclusive

### DATA DEPENDENCY ISSUES:

9. **Multi Class Nerd** - Complete games in 5 different genres
   - **Issue:** Are we tracking/identifying game genres?
   - **Status:** VERIFY - check if genre data exists

10. **Fearless** - Complete 3 horror games
    - **Issue:** User has completed horror games but doesn't have achievement
    - **Status:** BROKEN - either genre detection not working or missing data

11. **Big Brain Energy** - Complete 3 puzzle games
    - **Issue:** Same as Fearless - genre-based
    - **Status:** BROKEN - genre system not working

### BROKEN/NOT TRIGGERING:

12. **Rank Up IRL** - Reach certain StatusXP milestones
    - **Issue:** User at 15,000+ XP but doesn't have achievement
    - **Status:** BROKEN - achievement system not detecting or awarding properly
    - **Critical:** Questions integrity of entire achievement system

**Action Items:**
1. Audit entire achievement system - why aren't achievements triggering?
2. Verify genre data exists in database
3. Remove 5 achievements completely
4. Fix 3 achievements (adjust criteria)
5. Investigate genre-based achievements (3 affected)
6. Fix StatusXP milestone detection

---

## 6. New Achievement Structure - Platform-Specific Lists

### PlayStation (PSN) Achievements

**Trophy Total Milestones:**
- First Trophy — 1 trophy
- Getting Warm — 10 trophies
- Trophy Case — 50 trophies
- Shelf Builder — 100 trophies
- Vault Starter — 250 trophies
- Vault Keeper — 500 trophies
- The Hoard — 1,000 trophies
- Trophy Vault — 2,500 trophies
- Trophy Master — 5,000 trophies
- Trophy Legend — 7,500 trophies
- Trophy God — 10,000 trophies
- Trophy Immortal — 15,000 trophies

**Bronze Trophies:**
- Bronze Beginner — 25 bronze
- Bronze Collector — 100 bronze
- Bronze Hunter — 500 bronze
- Bronze Master — 1,000 bronze
- Bronze Hoarder — 2,500 bronze
- Bronze Legend — 5,000 bronze
- Bronze God — 7,500 bronze
- Bronze Immortal — 10,000 bronze

**Silver Trophies:**
- Silver Spark — 25 silver
- Silver Collector — 100 silver
- Silver Hunter — 500 silver
- Silver Master — 1,000 silver
- Silver Legend — 2,000 silver
- Silver God — 3,000 silver

**Gold Trophies:**
- Gold Spark — 10 gold
- Gold Collector — 50 gold
- Gold Hunter — 250 gold
- Gold Master — 500 gold
- Gold Legend — 750 gold
- Gold God — 1,000 gold

**Platinum Trophies:**
- Platinum Spark — 1 platinum
- Platinum Collector — 10 platinums
- Platinum Hunter — 25 platinums
- Platinum Master — 50 platinums
- Platinum Legend — 100 platinums
- Platinum God — 150 platinums
- Platinum Immortal — 200 platinums
- Platinum Deity — 250 platinums

**Rare Trophy Hunter:**
- Rare Find — Earn 1 rare trophy (<10% earned)
- Rare Collector — Earn 10 rare trophies
- Rare Hunter — Earn 25 rare trophies
- Rare Master — Earn 50 rare trophies
- Rare Legend — Earn 100 rare trophies
- Rare God — Earn 250 rare trophies

### Xbox Achievements

**Achievement Total Milestones:**
- First Unlock — 1 achievement
- Getting Started — 10 achievements
- Achievement Case — 50 achievements
- Shelf Builder — 100 achievements
- Vault Starter — 250 achievements
- Vault Keeper — 500 achievements
- The Hoard — 1,000 achievements
- Achievement Vault — 2,500 achievements
- Achievement Master — 5,000 achievements
- Achievement Legend — 7,500 achievements
- Achievement God — 10,000 achievements
- Achievement Immortal — 15,000 achievements

**Gamerscore Milestones:**
- Score Starter — 1,000G
- Score Builder — 5,000G
- Score Collector — 10,000G
- Score Hunter — 25,000G
- Score Master — 50,000G
- Score Legend — 75,000G
- Score God — 100,000G
- Score Titan — 150,000G
- Score Immortal — 200,000G
- Score Deity — 250,000G
- Score Eternal — 300,000G

**Game Completion:**
- First 100% — Complete 1 game (100%)
- Completionist — Complete 10 games
- Completion Hunter — Complete 25 games
- Completion Master — Complete 50 games
- Completion Legend — Complete 100 games
- Completion God — Complete 150 games

### Steam Achievements

**Achievement Total Milestones:**
- First Unlock — 1 achievement
- Getting Started — 10 achievements
- Achievement Case — 50 achievements
- Shelf Builder — 100 achievements
- Vault Starter — 250 achievements
- Vault Keeper — 500 achievements
- The Hoard — 1,000 achievements
- Achievement Vault — 2,500 achievements
- Achievement Master — 5,000 achievements
- Achievement Legend — 7,500 achievements
- Achievement God — 10,000 achievements
- Achievement Immortal — 15,000 achievements

**Perfect Games:**
- First Perfect — Complete 1 game (all achievements)
- Perfectionist — Complete 10 games
- Perfect Hunter — Complete 25 games
- Perfect Master — Complete 50 games
- Perfect Legend — Complete 100 games
- Perfect God — Complete 150 games

**Rare Achievement Hunter:**
- Rare Find — Earn 1 rare achievement (<10% earned)
- Rare Collector — Earn 10 rare achievements
- Rare Hunter — Earn 25 rare achievements
- Rare Master — Earn 50 rare achievements
- Rare Legend — Earn 100 rare achievements
- Rare God — Earn 250 rare achievements


### Cross-Platform Achievements
*(Requires all 3 platforms connected)*

**StatusXP Milestones (Combined Score):**
- **StatusXP**: 500 StatusXP total
- **StatusXP II**: 1,500 StatusXP total
- **StatusXP III**: 3,500 StatusXP total
- **StatusXP IV**: 7,500 StatusXP total
- **StatusXP V**: 15,000 StatusXP total
- **StatusXP VI**: 20,000 StatusXP total
- **StatusXP VII**: 25,000 StatusXP total

**Multi-Platform Mastery:**
- Platform Hopper — Earn achievements on all 3 platforms in 1 day
- Triple Threat — Earn 100+ achievements on each platform
- Universal Gamer — Earn 500+ achievements on each platform
- Platform Master — Earn 1,000+ achievements on each platform
- Ecosystem Legend — Earn 2,500+ achievements on each platform

**Same Game, All Platforms:**
- Double Dip — Complete same game on 2 different platforms
- Triple Play — Complete same game on all 3 platforms
- Triple Platinum — Earn platinum/100% on same game across all 3 platforms (if available)
- Collection Completionist — Complete 5 games across all platforms
- Platform Completionist — Complete 10 games across all platforms

**Combined Unlocks:**
- Multi-Platform Collector — 1,000 total unlocks (trophies + achievements) across all platforms
- Multi-Platform Hunter — 2,500 total unlocks across all platforms
- Multi-Platform Master — 5,000 total unlocks across all platforms
- Multi-Platform Legend — 10,000 total unlocks across all platforms
- Multi-Platform God — 15,000 total unlocks across all platforms

**Rare Hunter (Cross-Platform):**
- Rare Across Worlds — Earn 10 rare achievements (<10%) on each platform
- Triple Rare Hunter — Earn 25 rare achievements on each platform
- Universal Rare Master — Earn 50 rare achievements on each platform

**Game Library:**
- Multi-Platform Library — Own 50+ games across all platforms
- Diverse Collection — Own 100+ games across all platforms
- Universal Collector — Own 250+ games across all platforms

---

