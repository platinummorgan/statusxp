# Activity Feed Feature Design - SIMPLIFIED + AI-POWERED

## Overview
A collapsible activity feed showing **AI-generated stories** about aggregate stat changes, organized by date with unread counts.

**Core Value Prop:** 
- Users sync to see their progress announced with personality
- AI creates unique, engaging descriptions (no boring templates)
- Daily check-ins to see what others accomplished (unread badge)
- FOMO-driven retention ("What did I miss today?")

**Key Innovation: AI Personality**
- Every story is unique (no duplicate phrasing)
- Casual, enthusiastic tone ("🔥 on fire!", "crushing it!", "respect! 👊")
- Contextual awareness (milestone numbers get more hype)

---

## 1. What Gets Posted to Feed?

### Report EVERYTHING Philosophy
**"Until the feed gets mind-blowingly busy, show ALL changes"**
- ✅ No minimum thresholds - Even +1 StatusXP gets posted
- ✅ Show before/after values for context
- ✅ Detailed breakdowns (trophy types, specific counts)
- ✅ Game names included when relevant

**This is a CURRENT EVENTS feed:**
- Stories auto-delete after 7 days (1/1/2026 → deleted 1/8/2026)
- Not a history archive - just "what's happening now"
- Fresh, real-time community activity

### Auto-Generated Events (Track ALL Changes)

**StatusXP Changes:**
- "Dex-Morgan increased by 847 StatusXP (5,234 → 6,081)"
- Show any increase, no matter how small

**Platinum Count (PSN):**
- "XxThumperxX earned their 930th Platinum in Dishonored (929 → 930)"
- Always show with game name of most recent platinum

**Trophy Breakdown (PSN):**
- "Dex-Morgan earned 2 Gold, 5 Silver, 15 Bronze in God of War"
- Show counts for Gold/Silver/Bronze even if one type is 0
- Example: "Got 15 Bronze trophies in God of War (0 → 15)"

**Gamerscore Changes (Xbox):**
- "Spacemang increased Gamerscore by 500 (6,000 → 6,500)"
- Show any increase

**Achievement Count (Steam):**
- "SteamUser earned 47 achievements today"
- Track total achievement count changes

### No Exclusions!
- Everything gets posted (until we need to add filters)
- More data = more engagement
- Users love seeing granular progress

---

## 2. Database Schema

### `user_stat_snapshots` Table (Track State Over Time)
```sql
-- Stores user stats at each sync for comparison
CREATE TABLE user_stat_snapshots (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Snapshot data
  total_statusxp INT NOT NULL,
  platinum_count INT DEFAULT 0,
  gamerscore INT DEFAULT 0, -- Xbox only
  psn_trophy_count INT DEFAULT 0, -- Total PSN trophies
  steam_achievement_count INT DEFAULT 0, -- Total Steam achievements
  
  -- Recent game (for context in AI generation)
  latest_game_title TEXT,
  latest_platform_id INT,
  
  -- Timing
  synced_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- One snapshot per sync
  CONSTRAINT unique_user_sync UNIQUE(user_id, synced_at)
);

CREATE INDEX idx_snapshots_user_time ON user_stat_snapshots(user_id, synced_at DESC);
```

### `activity_feed` Table (AI-Generated Stories)
```sql
CREATE TABLE activity_feed (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- AI-generated content
  story_text TEXT NOT NULL, -- "Dex-Morgan is on fire! 🔥 Just boosted gamerscore from 6000 to 6500!"
  
  -- Metadata for filtering/sorting
  event_type TEXT NOT NULL, -- 'statusxp_gain', 'platinum_milestone', 'gamerscore_gain', 'trophy_detail'
  change_type TEXT, -- 'small', 'medium', 'large', 'milestone' (for AI prompt context)
  
  -- Raw change data (for analytics and before/after display)
  old_value INT,
  new_value INT,
  change_amount INT,
  
  -- Trophy breakdowns (PSN only)
  gold_count INT DEFAULT 0,
  silver_count INT DEFAULT 0,
  bronze_count INT DEFAULT 0,
  
  -- Context
  game_title TEXT, -- If related to specific game
  platform_id INT,
  
  -- Display
  username TEXT NOT NULL, -- Denormalized for performance
  avatar_url TEXT,
  
  -- Timing
  event_date DATE NOT NULL, -- For grouping by date
  created_at TIMESTAMPTZ DEFAULT NOW(),
  expires_at DATE NOT NULL, -- Auto-calculated: event_date + 7 days
  
  -- Privacy
  is_visible BOOLEAN DEFAULT true,
  
  -- Generation metadata
  ai_model TEXT DEFAULT 'gpt-4o-mini', -- Track which model generated it
  generation_failed BOOLEAN DEFAULT false, -- Fallback to template if true
  
  -- Multiple stories per user per day (removed unique constraint)
  -- User can have statusxp_gain + platinum_milestone + trophy_detail same day
  CHECK (expires_at = event_date + INTERVAL '7 days')
);

CREATE INDEX idx_activity_feed_date ON activity_feed(event_date DESC) WHERE is_visible = true;
CREATE INDEX idx_activity_feed_expires ON activity_feed(expires_at); -- For auto-cleanup
CREATE INDEX idx_activity_feed_created ON activity_feed(created_at DESC);
CREATE INDEX idx_activity_feed_user ON activity_feed(user_id);

-- Auto-cleanup function: Delete stories older than 7 days
CREATE OR REPLACE FUNCTION cleanup_old_activity_feed()
RETURNS void AS $$
BEGIN
  DELETE FROM activity_feed
  WHERE expires_at < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- Schedule cleanup daily (requires pg_cron extension)
-- SELECT cron.schedule('cleanup-activity-feed', '0 2 * * *', 'SELECT cleanup_old_activity_feed()');
```

### `activity_feed_views` Table (Track Read Status)
```sql
-- Same as before, no changes
CREATE TABLE activity_feed_views (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  last_viewed_at TIMESTAMPTZ DEFAULT NOW(),
  last_viewed_id BIGINT,
  PRIMARY KEY(user_id)
);

CREATE OR REPLACE FUNCTION get_unread_activity_count(p_user_id UUID)
RETURNS INT AS $$
  SELECT COUNT(*)::INT
  FROM activity_feed af
  WHERE af.is_visible = tru (AI-Powered)

### Sync Flow Overview
```
1. User initiates sync
2. BEFORE sync: Create snapshot of current stats
3. Sync runs (fetch achievements, update database)
4. AFTER sync: Create new snapshot
5. Compare snapshots → Detect changes
6. For each change → Generate AI story → Insert into activity_feed
7. Sync complete
```

### Step-by-Step Implementation

#### Step 1: Pre-Sync Snapshot
```javascript
// In sync service, before fetching new data
async function createPreSyncSnapshot(userId) {
  const profile = await supabase
    .from('profiles')
    .select('total_statusxp')
    .eq('id', userId)
    .single();
    
  const platinumCount = await supabase
    .from('user_achievements')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('trophy_type', 'platinum')
    .in('platform_id', [1, 2, 5, 9]);
    
  // Get latest game title for context
  const latestGame = await supabase
    .from('user_games')
    .select('game_title, platform_id')
    .eq('user_id', userId)
    .order('last_played_at', { ascending: false })
    .limit(1)
    .single();
  
  const snapshot = await supabase
    .from('user_stat_snapshots')
    .insert({
      user_id: userId,
      total_statusxp: profile.data.total_statusxp,
      platinum_count: platinumCount.count,
      latest_game_title: latestGame.data?.game_title,
      latest_platform_id: latestGame.data?.platform_id,
    })
    .select()
    .single();
    
  return snapshot.data;
}
```

#### Step 2: Post-Sync Comparison & AI Generation
```javascript
async function generateActivityStories(userId, preSnapshot) {
  // Get current stats (post-sync)
  const postSnapshot = await createPostSyncSnapshot(userId);
  
  const changes = detectChanges(preSnapshot, postSnapshot);
  
  // Generate AI story for each change
  for (const change of changes) {
    await generateAndInsertStory(userId, change, postSnapshot);
  }
}

function detectChanges(before, after) {
  const changes = [];
  
  // StatusXP change (report ANY increase)
  if (after.total_statusxp > before.total_statusxp) {
    changes.push({
      type: 'statusxp_gain',
      oldValue: before.total_statusxp,
      newValue: after.total_statusxp,
      change: after.total_statusxp - before.total_statusxp,
      changeType: categorizeChange(after.total_statusxp - before.total_statusxp, 'statusxp'),
    });
  }
  
  // Platinum milestone (with game name)
  if (after.platinum_count > before.platinum_count) {
    changes.push({
      type: 'platinum_milestone',
      oldValue: before.platinum_count,
      newValue: after.platinum_count,
      change: after.platinum_count - before.platinum_count,
      changeType: 'milestone',
      gameTitle: after.latest_game_title, // Most recent platinum game
    });
  }
  
  // Trophy breakdown by type (Gold/Silver/Bronze)
  // Compare trophy counts per game if we have that data, or total counts
  if (after.gold_trophy_count > before.gold_trophy_count ||
      after.silver_trophy_count > before.silver_trophy_count ||
      after.bronze_trophy_count > before.bronze_trophy_count) {
    changes.push({
      type: 'trophy_detail',
      goldCount: after.gold_trophy_count - before.gold_trophy_count,
      silverCount: after.silver_trophy_count - before.silver_trophy_count,
      bronzeCount: after.bronze_trophy_count - before.bronze_trophy_count,
      oldGold: before.gold_trophy_count,
      oldSilver: before.silver_trophy_count,
      oldBronze: before.bronze_trophy_count,
      gameTitle: after.latest_game_title,
    });
  }
  
  // Gamerscore (Xbox - ANY increase)
  if (after.gamerscore > before.gamerscore) {
    changes.push({
      type: 'gamerscore_gain',
      oldValue: before.gamerscore,
      newValue: after.gamerscore,
      change: after.gamerscore - before.gamerscore,
    });
  }
  
  // Steam achievements (ANY increase)
  if (after.steam_achievement_count > before.steam_achievement_count) {
    changes.push({
      type: 'steam_achievement_gain',
      oldValue: before.steam_achievement_count,
      newValue: after.steam_achievement_count,
      change: after.steam_achievement_count - before.steam_achievement_count,
    });
  }
  
  return changes;
}

function categorizeChange(amount, type) {
  // Determine hype level for AI prompt
  if (type === 'statusxp') {
    if (amount < 100) return 'small';
    if (amount < 500) return 'medium';
    if (amount < 1000) return 'large';
    return 'massive';
  }
  // Similar logic for other types
}
```

#### Step 3: AI Story Generation
```javascript
async function generateAndInsertStory(userId, change, snapshot) {
  const username = await getDisplayName(userId, change.type);
  
  // Build AI prompt
  const prompt = buildPrompt(username, change, snapshot);
  
  // Call OpenAI
  let storyText;
  let generationFailed = false;
  
  try {
    const response = await openai.chat.completions.create({
      model: 'gpt-4o-mini',
      messages: [
        {
          role: 'system',
          content: `You are a hype announcer for StatusXP, a gaming achievement tracker. 
                    Generate short, enthusiastic social media posts about user accomplishments.
                    Keep it casual, fun, and varied - no two posts should sound identical.
                    Use emojis sparingly (0-1 per post). Max 150 characters.`
        },
        {
          role: 'user',
          content: prompt
        }
      ],
      temperature: 0.9, // High creativity for variety
      max_tokens: 60,
    });
    
    storyText = response.choices[0].message.content.trim();
  } catch (error) {
    console.error('AI generation failed:', error);
    generationFailed = true;
    // Fallback to template
    storyText = buildTemplateStory(username, change);
  }
  
  // Insert into activity_feed
  await supabase
    .from('activity_feed')
    .insert({ (AI-Generated Examples)
```
[Avatar] AI-generated story text
         Time ago
         
Real examples AI might generate:

StatusXP Gains:
• "Dex-Morgan is on fire! 🔥 Just earned 847 StatusXP!"
• "Nice work! X_imThumper_X added 234 StatusXP today."
• "BOOM! Spacemang just CRUSHED 1,547 StatusXP! 💪"

Platinum Milestones:
• "XxThumperxX just platinumed Dishonored! That's #930! 🏆"
• "HUGE MILESTONE! Dex-Morgan hit their 100TH PLATINUM in Elden Ring! 🎉"
• "Respect! SteamUser earned their 5th platinum trophy."

Gamerscore:
• "Spacemang jumped 500 Gamerscore (6000 → 6500). Keep grinding!"
• "Xbox grind never stops! User gained 250 Gamerscore today."
• "Whoa! 1,000 Gamerscore gain for XboxPro! That's dedication! 🎮"
```

### Personality Guidelines for AI
- **Casual tone:** Like a hype friend, not corporate
- **Vary energy:** Small gains = chill, big gains = HYPE
- **Milestone awareness:** 100th, 500th, 1000th get special treatment
- **Emoji sparingly:** 0-1 per post max
- **Keep it short:** 80-150 characters ideal
- **No repetition:** Temperature 0.9 ensures variety   event_date: new Date().toISOString().split('T')[0],
      generation_failed: generationFailed,
    })
    .onConflict(['user_id', 'event_type', 'event_date'])
    .merge(); // Update if already exists today
}
```

#### Step 4: AI Prompt Engineering
```javascript
function buildPrompt(username, change, snapshot) {
  const { type, oldValue, newValue, change: amount, changeType, gameTitle } = change;
  
  switch (type) {
    case 'statusxp_gain':
      return `${username} just gained ${amount} StatusXP (${oldValue} → ${newValue}).
              Change magnitude: ${changeType}.
              ALWAYS include before/after values in parentheses.
              Write a ${changeType === 'massive' ? 'very exciting' : 'upbeat'} announcement.
              Examples of tone:
              - Small: "Nice! ${username} added 47 StatusXP (5,234 → 5,281)."
              - Large: "${username} is crushing it! 🔥 Gained 847 StatusXP (10,500 → 11,347)!"
              - Massive: "WHOA! ${username} just EXPLODED with 2,134 StatusXP (15k → 17k)!"`;
              
    case 'trophy_detail':
      const trophyParts = [];
      if (change.goldCount > 0) trophyParts.push(`${change.goldCount} Gold`);
      if (change.silverCount > 0) trophyParts.push(`${change.silverCount} Silver`);
      if (change.bronzeCount > 0) trophyParts.push(`${change.bronzeCount} Bronze`);
      const trophyList = trophyParts.join(', ');
      
      return `${username} earned ${trophyList} trophies in ${gameTitle}.
              Gold: ${change.oldGold} → ${change.oldGold + change.goldCount}
              Silver: ${change.oldSilver} → ${change.oldSilver + change.silverCount}
              Bronze: ${change.oldBronze} → ${change.oldBronze + change.bronzeCount}
              Write a celebratory announcement mentioning the trophy types.
              Examples:
              - "${username} snagged 15 Bronze trophies in God of War! (0 → 15)"
              - "Trophy hunt! ${username} grabbed 2 Gold, 5 Silver in Elden Ring!"
              - "${username} cleaned up! 1 Gold, 3 Silver, 10 Bronze in Dishonored."`;
  }
}
              & Cost Considerations

### OpenAI API Costs
**gpt-4o-mini pricing (as of 2025):**
- ~$0.00015 per request (with 60 tokens max)
- Daily user syncs: ~50 users × 1 sync/day = 50 stories/day
- Monthly cost: 50 stories/day × 30 days × $0.00015 = **$0.23/month**
- With 500 users: **$2.25/month**
- With 5,000 users: **$22.50/month**

**Cost is negligible** - Worth it for personality and engagement.

### Caching Strategy
- **Snapshots:** Keep last 30 days, delete older
- **Activity feed:** Auto-delete after 7 days (rolling window)
- **Dashboard preview:** Cache for 5 minutes
- **Unread counts:** Real-time query (fast with index)

### Auto-Cleanup Job
```sql
-- Run daily at 2 AM to purge expired stories
DELETE FROM activity_feed WHERE expires_at < CURRENT_DATE;

-- Or use pg_cron:
SELECT cron.schedule('cleanup-activity-feed', '0 2 * * *', 
  'DELETE FROM activity_feed WHERE expires_at < CURRENT_DATE');
```

**7-Day Rolling Window:**
- Story posted 1/1/2026 → `expires_at` = 1/8/2026
- On 1/8/2026 at 2 AM → Story deleted automatically
- Feed always shows max 7 days of recent activity

### Rate Limiting
- Maximum 1 AI generation per user per event type per day
- If sync fails and retries, reuse existing story (don't regenerate)
- Batch snapshots if user syncs multiple platform
function buildTemplateStory(username, change) {
  switch (change.type) {
    case 'statusxp_gain':
      return `${username} gained ${change.change} StatusXP (${change.oldValue} → ${change.newValue})`;
    case 'platinum_milestone':
      return `${username} earned their ${getOrdinal(change.newValue)} platinum in ${change.gameTitle}`;
    case 'gamerscore_gain':
      return `${username} increased Gamerscore by ${change.change} (${change.oldValue} → ${change.newValue})`;
    default:
      return `${username} made progress in StatusXP`;
  }
}
```

-- Get previous count from last post or 0
old_plat_count = SELECT new_value FROM activity_feed
                 WHERE user_id = user_id 
                 AND event_type = 'platinum_milestone'
                 ORDER BY created_at DESC LIMIT 1

-- If new platinum earned, post with game name
IF new_plat_count > old_plat_count THEN
  game_title = (SELECT game_title FROM most recent platinum)
  INSERT INTO activity_feed (...) VALUES (
    ..., 'platinum_milestone', old_plat_count, new_plat_count, 1,
    CURRENT_DATE, username, game_title
  )
END IF
```

#### Gamerscore Changes (Xbox)
```sql
-- Similar logic to StatusXP but for Xbox gamerscore field
-- Only triggers if user has Xbox account linked
```

### Daily Rollup Strategy
- **One post per event type per day** (enforced by UNIQUE constraint)
- Example: User syncs 3 times in one day gaining StatusXP each time
  - First sync: Creates post "increased by 500 StatusXP"
  - Second sync: Updates same post to "increased by 850 StatusXP" (cumulative)
  - Third sync: Updates to "increased by 1,200 StatusXP"
- Prevents spam, shows daily totals

### Post Timing
- Posts created **immediately after sync** (not delayed)
- Timestamp shows when sync completed
- Date grouping based on user's local date (event_date column)

---

## 5. UI/UX Design (Optional - Phase 2)

### When to Notify?
1. **Daily digest** - "12 new updates in StatusXP feed today"
2. **Milestone reactions** (future) - Comments/kudos on your posts

### Notification Settings
Users control:
- ❌ Daily digest (default: OFF, opt-in only)
- ❌ Individual post notifications (too noisy)

### Push Notification Timing
- **Daily at 6pm local time:** "Check out what 12 users accomplished today!"
- Only if unread count > 0
- Max once per day

**Note:** No like/comment notifications in Phase 1 - keeping it simple
└────────────────────────────────────────────┘
```

### Dashboard Section (Collapsible)
Located below AVG/GAMES section on dashboard:

```
┌─────────────────────────────────────────────────┐
│ 📰 What are fellow StatusXP chasers up to!? (+4)│  ← Click to expand
└─────────────────────────────────────────────────┘
    ↓ (Expanded)
┌─────────────────────────────────────────────────┐
│ 📰 What are fellow StatusXP chasers up to!?     │
├─────────────────────────────────────────────────┤
│ > 2/6/2026 (+2)                                 │  ← Click to expand
│ > 2/5/2026 (+2)                                 │
│ > 2/4/2026 (0) [read]                           │
└─────────────────────────────────────────────────┘
    ↓ (2/6/2026 expanded)
┌─────────────────────────────────────────────────┐
│ > 2/6/2026 (+2)                                 │
│   ├─ [PSN Avatar] Dex-Morgan increased by      │
│   │  847 StatusXP                               │
│   │  2 hours ago                                │
│   ├─ [Xbox Avatar] Spacemang gained 500         │
│   │  Gamerscore (6000 → 6500)                   │
│   │  5 hours ago                                │
│ > 2/5/2026 (+2)                                 │
└─────────────────────────────────────────────────┘
```

### Individual Story Format
```
[Avatar] Username performed action
         Time ago
         
Examples:
• Dex-Morgan increased by 847 StatusXP
• XxThumperxX earned their 930th Platinum in Dishonored
• Spacemang gained 500 Gamerscore (6000 → 6500)
• SteamUser earned 47 achievements today
```

### Interaction States
1. **Collapsed:** Show unread badge only
2. **Expanded (dates):** Show list of dates with unread counts
3. **Expanded (stories):** Show all stories for that date

### Badge Logic
- Badge shows total unread across all dates
- Clicking date marks all stories in that date as read
- Badge persists until user views feed section
- Resets on page refresh after viewing

### Empty States
- **No activity:** "No activity yet. Sync to share your progress!"
- **All caught up:** "You're all caught up! ✓"
- **No new posts today:** Show most recent date with activity
- **Immediate:** Likes (batched if multiple in 5 min window)
- **Daily at 6pm:** Digest of all activity that day

---

## 7. Performance Considerations

### Feed Query Optimization
```sql
-- Get feed with pagination
SELECT 
  af.*,
  p.username,
  p.psn_online_id,
  p.xbox_gamertag,
  p.avatar_url,
  EXISTS(
    SELECT 1 FROM activity_likes 
    WHERE activity_id = af.id 
    AND user_id = $current_user_id
  ) as user_has_liked
FROM activity_feed af
JOIN profiles p ON af.user_id = p.id
WHERE af.is_visible = true
  AND p.show_on_leaderboard = true
ORDER BY af.posted_at DESC
LIMIT 20 OFFSET $offset;
```

### Caching Strategy
- **Dashboard preview:** Cache for 5 minutes (fast refresh on pull-to-refresh)
- **Full feed:** Real-time, no cache
- **Like counts:** Denormalized in `activity_feed.like_count` (updated via trigger)

### Image Loading
- Use game covers from existing `games` table
- Achievement icons already proxied through Supabase storage
- Lazy load images as user scrolls

---

## 8. StatusXP Integration

### Does Feed Activity Grant StatusXP?
**No new StatusXP for posting** - Would be exploited
- User already earned StatusXP for the achievement itself
- Like system is purely social validation

### Show StatusXP Gains in Feed
- ✅ Display how much StatusXP the achievement was worth
- Example: "🏆 Platinum • 847 StatusXP"
- Reinforces value of rare achievements

---

## 9. Rollout Strategy

### Phase 1: MVP (Week 1)
- ✅ Database tables
- ✅ Feed generation during sync (platinums + ultra rare only)
- ✅ Dashboard preview section (top 5)
- ✅ Full feed screen (/activity-feed route)
- ✅ Like/unlike functionality
- ✅ No notifications yet

### Phase 2: Polish (Week 2)
- ✅ Add very rare + rare achievements to feed
- ✅ Like notifications (push + in-app)
- ✅ "Who liked" user list modal
- ✅ Hide post functionality
- ✅ Empty states & error handling

### Phase 3: Social Features (Week 3-4)event platform

**Recommendation:** Use event platform (StatusXP = display platform, Gamerscore = Xbox GT, Platinum = PSN ID)

### 2. StatusXP Event - Show All or Threshold?
- Option A: Any StatusXP gain (even +10) shows in feed
- Option B: Minimum threshold (100+) to reduce noise
- Option C: Only show if daily total > 500

**Recommendation:** Show all gains initially, add threshold if feed too noisy

### 3. Date Grouping - How Far Back?
- Option A: Show last 30 days of dates
- Option B: Show last 7 days, then "Older" section
- Option C: Infinite scroll through all history

**Recommendation:** Show last 14 days grouped, "View Older" button for rest

### 4. Avatar Size & Styling
- Circular avatars (16x16, 24x24, 32x32?)
- Show platform icon overlay (PSN logo, Xbox logo)?
- Colored border based on platform?

**Recommendation:** 24x24 circular with subtle platform indicator

### 5. Unread Badge Persistence
- Resets when user opens section? Or when they expand dates?
- Persists across app restarts?
- Stored locally or in database?

**Recommendation:** Store `last_viewed_at` in database, resets when section expanded

### 6. Likes/Reactions?
User wants simple feed, but should there be any engagement?
- Option A: No engagement, pure info feed
- Option B: Simple "👍" reaction (no comments)
- Option C: Full like system from original design

**Recommendation:** Start with no engagement (Phase 1), add reactions in Phase 2 if requested
Which name shows in feed?
- Option A: PSN ID if linked, else Xbox, else Steam
- Option B: User's "display platform" preference
- Option C: Platform-specific name based on achievement platform

**Recommendation:** Match achievement platform (earned on PSN → show PSN ID)

### 2. Multiple Platform Posts
User earns same achievement on PS4 and PS5:
- Show both in feed? (Seems spammy)
- Merge into one post? (Loses per-platform credit)
- Only show first earned?

**Recommendation:** Show first earned only, note stack in post ("Also on PS5")

### 3. Spam Prevention
User syncs huge game library for first time:
- Posts 100+ ultra rare achievements at once
- Floods entire feed

**Solution A:** Max posts per sync (10-20)
**Solution B:** Only post achievements earned in last 7 days
**Solution C:** Batch into "X earned 47 achievements in [Game]"

**Recommendation:** Combination of B + C

### 4. Feed Sort Order
- Posted time (most recent first) ← Default
- Like count (trending)
- StatusXP value (most impressive)
- Rarity (rarest first)

**Recommendation:** Default to recency, add "Trending" tab later

### 5. Like Limit?
Can users spam-like posts?
- Unlimited likes ← Simple, works like Twitter
- Daily like limit ← Prevents manipulation
- No self-likes ← Obvious

**Recommendation:** No self-likes, unlimited otherwise

---

## 12. Edge Cases to Handle

### Deleted Achievements
- Game removed from PSN/Xbox store
- Achievement later revoked (cheat detection)
- **Solution:** Cascade delete posts when achievement deleted

### Changed Usernames
- User changes PSN ID / Xbox gamertag
- Old posts show old name
- **Solution:** Denormalize name at post time, don't update retroactively

### Private Profile After Posting
- User sets `show_on_leaderboard = false` after posting
- **Solution:** Hide all future posts, keep existing posts visible (fair use)

### Time Zone Display
- Show "2 hours ago" in viewer's local time
- Store `posted_at` in UTC, format client-side

### Deleted User Account
- All posts cascade delete via `ON DELETE CASCADE`
- Likes from deleted users also cascade delete

---

## 13. Privacy & Legal Considerations

### GDPR Compliance
- Users can request data export (include feed posts + likes)
- Users can request deletion (cascade deletes handle this)

### Content Moderation
- No user-generated text initially (just achievement data)
- Future comments feature needs moderation system
- Report button for inappropriate usernames

### Age Restrictions
- PSN/Xbox/Steam already age-gate accounts
- No additional restrictions needed

---

## Success Metrics

### Launch Targets (Month 1)
- 60% of active users view feed at least once
- 30% of users like at least one post
- 10% increase in daily sync frequency
- Average 2+ feed views per daily active user

### Growth Targets (Month 3)
- 80%+ of users view feed weekly
- 50%+ of posts receive at least one like
- 20% increase in DAU (daily active users)
- Feed is #1 most-visited screen after dashboard

---

## Next Steps

### Before Implementation
1. **User research:** Ask 5-10 current users if they'd use this feature
2. **Design mockups:** Get pixel-perfect UI designs
3. **Platform priority:** Start with PSN-only, add Xbox/Steam in Phase 2?
4. **Name bikeshedding:** "Activity Feed" vs "Community" vs "Showcase"?

### After Planning Approval
1. Create database migration
2. Update sync services to generate posts
3. Build Flutter UI components
4. Deploy behind feature flag
5. Beta test with 10 users
6. Full rollout

---

## Appendix: Alternative Approaches

### A. Stories Instead of Feed
- 24-hour ephemeral posts (Instagram Stories style)
- Creates urgency but no lasting record
- **Verdict:** Too trendy, doesn't fit achievement tracking

### B. Weekly Digest Only
- No live feed, just email/push with highlights
- Lower engagement but less overwhelming
- **Verdict:** Good for Phase 3, not replacement for feed

### C. Leaderboard Integration
- Add "Recent" tab to leaderboard showing recent achievements
- Reuses existing screen
- **Verdict:** Consider as alternative to dashboard preview

### D. Discord Bot Integration
- Post to Discord when users earn achievements
- Extends social reach beyond app
- **Verdict:** Great for Phase 4, community growth feature
