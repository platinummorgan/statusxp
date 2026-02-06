# 🏆 StatusXP Competition Guidelines

## Overview

Welcome to the StatusXP Competition! Compete against other players for a chance to win a **$50 gift card** (PSN, Xbox, or Steam - winner's choice).

Competitions run for a **limited time period** (typically 1-2 weeks) and use a **fair percentage-based scoring system** that levels the playing field for all players regardless of their starting point or library size.

---

## How Scoring Works

### The Formula

Your competition score is calculated as:

```
Competition Score = (Points Gained / Potential at Competition End) × 100
```

**Where:**
- **Points Gained** = Your StatusXP at competition end - Your StatusXP at competition start
- **Potential at Competition End** = Total possible StatusXP from all games in your library (measured at competition end)

### Why This Is Fair

This formula ensures fairness by:

✅ **Rewards effort, not library size** - Players with smaller libraries can compete equally with those who have massive collections

✅ **Accounts for different starting points** - Someone at 90% completion can still win by improving their percentage

✅ **Natural anti-cheat** - Adding new games during the competition increases your denominator, making it HARDER to win unless you complete them

---

## Real Example

**Competition Period:** Feb 10-17, 2026 (1 week)

### Player A (Casual Library)
- **Start:** 10,000 StatusXP with 30,000 potential
- **Gains:** 2,000 StatusXP during competition
- **End:** 12,000 StatusXP with 30,000 potential
- **Score:** 2,000 / 30,000 = **6.67%**

### Player B (Large Library)  
- **Start:** 100,000 StatusXP with 250,000 potential
- **Gains:** 5,000 StatusXP during competition
- **End:** 105,000 StatusXP with 250,000 potential
- **Score:** 5,000 / 250,000 = **2.00%**

**Winner: Player A** despite gaining fewer raw points!

---

## Adding Games During Competition

### What Happens

If you add new games to your library during the competition:

- ✅ **You CAN earn points** from those new games (counts toward numerator)
- ⚠️ **Your potential INCREASES** (makes denominator bigger)
- ❌ **Your score becomes HARDER to improve** (unless you complete those games)

### Example: Gaming the System Backfires

**Player trying to cheat:**
- Start: 50,000 / 100,000 potential
- Adds 50 easy games: +25,000 potential
- Only completes 10 of them: +5,000 earned
- **Score:** 5,000 / 125,000 = **4.00%**

**Player grinding existing library:**
- Start: 50,000 / 100,000 potential  
- Adds no games
- Grinds hard on existing games: +5,000 earned
- **Score:** 5,000 / 100,000 = **5.00%**

**Winner: The grinder!** The cheater's score was diluted by adding games they didn't complete.

### Strategic Advice

**Best strategy:** Focus on completing achievements in games you already own rather than adding new ones unless you're confident you can complete them during the competition period.

---

## Sync Requirements & Platform Rules

### Before Entering Competition

**ALL connected platforms must be synced within 24 hours of entry:**

- ✅ If you have PSN connected: `last_psn_sync_at` must be fresh
- ✅ If you have Xbox connected: `last_xbox_sync_at` must be fresh
- ✅ If you have Steam connected: `last_steam_sync_at` must be fresh

**Entry Process:**
1. Click "Enter Competition"
2. System checks all your platform sync dates
3. If any are stale (>24 hours): "Please sync [Platform] before entering"
4. Once all fresh: Your starting snapshot is locked
5. You're entered! The platforms you entered with are now LOCKED

### During Competition

**You CAN:**
- ✅ Sync your platforms anytime to update progress
- ✅ Earn achievements from any game in your library
- ✅ Add new games (but this increases your potential = harder to win)

**You CANNOT:**
- ❌ Add NEW platforms mid-competition (locked at entry)
- ❌ Remove platforms you entered with
- ❌ Enter after competition starts

### Platform Lock System

**Example:**
- You enter with PSN + Xbox on Feb 15
- During competition you link Steam account
- **Steam achievements won't count** - you entered with PSN + Xbox only
- Next competition you can enter with all three

This prevents gaming the system by selectively adding easy platforms mid-competition.

---

## Multi-Platform Strategy

### Does Having Multiple Platforms Help or Hurt?

**Neither! It's naturally balanced.**

**Single Platform Player:**
- Potential: 100,000 StatusXP
- Gains 5,000 from focused grinding
- **Score: 5.0%**

**Multi-Platform Player (Equal Effort Across All):**
- Potential: 300,000 StatusXP (100k × 3 platforms)
- Gains 15,000 (5k per platform)
- **Score: 5.0%** (SAME!)

**Multi-Platform Player (Only Grinds One):**
- Potential: 300,000 StatusXP
- Gains 5,000 (only from one platform)
- **Score: 1.67%** (WORSE!)

### Strategic Implications

✅ **Single-platform advantage:** 100% focus on one ecosystem  
✅ **Multi-platform advantage:** More variety, more opportunities  
⚠️ **Multi-platform challenge:** Must grind ALL platforms equally

The formula naturally rewards **effort relative to your own library**, not absolute achievement counts.

---

## Rules & Eligibility

### Who Can Participate

- ✅ All users with an active StatusXP account
- ✅ Must have `show_on_leaderboard = true` in profile settings
- ✅ Must have synced at least one platform (PSN, Xbox, or Steam)
- ✅ All platforms must be synced within 24 hours before entry

### Fair Play

- ✅ All achievement earning must be legitimate gameplay
- ❌ No cheating, exploiting, or using save file manipulation
- ❌ No creating multiple accounts to game the system
- ⚠️ Suspicious activity (e.g., earning 1000s of achievements in minutes) will be investigated

### Verification

- Achievements are verified through official platform APIs (PSN, Xbox, Steam)
- Competition organizers reserve the right to request proof of gameplay
- Violations may result in disqualification and account suspension

---

## Prize

**Winner receives:** $50 digital gift card for platform of choice:
- PlayStation Network (PSN)
- Xbox Store  
- Steam

**Prize delivery:** Within 7 days of competition end via email

**Tiebreaker:** If multiple players have the same percentage (to 2 decimal places), the player with the higher raw StatusXP gain wins.

---

## Competition Timeline

Each competition follows a structured schedule:

### Phase 1: Announcement (5-7 days)
- Competition announced with rules and prize
- Countdown timer shown in app
- Users can review guidelines
- **Cannot enter yet** - builds anticipation

### Phase 2: Entry Window (2-3 days)
- Entry opens at announced time
- Must sync all connected platforms
- Starting snapshot taken at entry time
- Platform selection locked
- Entry closes when competition starts

### Phase 3: Competition Period (7-14 days)
- Competition officially starts at exact UTC time
- Earn achievements on any entered platform
- Sync anytime to update leaderboard
- Leaderboard updates hourly
- Competition ends at exact UTC time

### Phase 4: Verification (1-2 days)
- Review for suspicious activity
- Validate winner's achievement timestamps
- Check for rule violations
- Final scores calculated

### Phase 5: Winner Announcement (Within 7 days)
- Winner announced publicly
- Prize delivery initiated
- Competition results archived

### Example Timeline

**Real Competition Schedule:**
- **Feb 10, 12:00 AM UTC** - Announcement posted
- **Feb 15, 12:00 AM UTC** - Entry window opens
- **Feb 17, 12:00 AM UTC** - Competition starts, entry closes
- **Feb 24, 11:59 PM UTC** - Competition ends (exactly 7 days)
- **Feb 25-26** - Verification period
- **Feb 27** - Winner announced
- **Mar 1** - Prize delivered

### Time Zone Handling

- ✅ All times shown in **your local timezone** in the app
- ✅ Actual competition uses **UTC timestamps** for fairness
- ✅ Entry/Start/End times are **exact** (no grace periods)
- ✅ Countdown timers update in real-time

**Example:**
- Competition starts: Feb 17, 12:00 AM UTC
- **You see (PST):** Feb 16, 4:00 PM
- **You see (EST):** Feb 16, 7:00 PM
- **You see (GMT):** Feb 17, 12:00 AM

### Important Notes

- Starting snapshot taken at **entry time** (not competition start)
- Ending snapshot taken at competition end time
- Only achievements earned **between entry and end** count
- Achievements earned before entry don't count (even during entry window)
- Late entries not accepted after competition starts

---

## Leaderboard

During the competition, you can view:

- **Your current score** - Live percentage based on current progress
- **Your rank** - Where you stand among all participants
- **Top 10** - Current leaders and their scores
- **Time remaining** - Countdown to competition end

Leaderboard updates **hourly** during the competition.

---

## Frequently Asked Questions

**Q: Can I participate if I just joined StatusXP?**  
A: Yes! The percentage-based system means new players can compete fairly.

**Q: What if I'm already at 90% completion?**  
A: You can still win! The formula measures improvement relative to remaining potential.

**Q: Does buying new games help or hurt me?**  
A: It hurts unless you complete them. New games increase your denominator (potential), making your percentage harder to improve.

**Q: Can I add new platforms during the competition?**  
A: No. The platforms you enter with are locked. You can link new platforms to your account, but their achievements won't count for this competition.

**Q: What if I forgot to sync before entering?**  
A: The entry system will block you and show which platforms need syncing. Just sync and try again.

**Q: Do I have to sync during the competition?**  
A: Not required, but recommended! Your leaderboard position won't update until you sync. We recommend syncing daily.

**Q: What if the platform APIs are down?**  
A: Competition organizers will extend deadlines if there's widespread API downtime affecting multiple participants.

**Q: What if MY sync fails but others are working?**  
A: Try again later. If persistent issues, contact support. We don't extend deadlines for individual technical issues.

**Q: Can I see other players' detailed stats?**  
A: You can see their competition score percentage and rank, but not their exact gains/potential for privacy.

**Q: How do you prevent cheating?**  
A: We verify achievement timestamps with platform APIs, check for suspicious patterns (1000s of achievements in minutes), and manually review the winner.

**Q: What if I have multiple accounts?**  
A: Only one entry per person. Multiple accounts competing is prohibited and will result in disqualification.

**Q: Can I win multiple times?**  
A: Yes! But we may limit frequency (e.g., can't win consecutive competitions) to spread opportunities.

**Q: What time zone should I use for planning?**  
A: Use the countdown timer in the app - it automatically converts to your local time.

---

## Good Luck!

May the best grinder win! 🎮

Remember: **Quality over quantity** - Focus on completing what you have rather than expanding your library during competition.

---

*Competition rules subject to change. Participants will be notified of any rule changes before they take effect.*
