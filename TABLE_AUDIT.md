# DATABASE TABLE AUDIT (Updated 2026-01-25)

Source of truth for this update: DATABASE_SCHEMA_LIVE.sql

## 📊 **TOTAL TABLE COUNT: 31**

## ✅ **CORE & IDENTITY**
| Table | Purpose | Status |
|-------|---------|--------|
| `profiles` | User accounts | ✅ Production |
| `platforms` | Platform reference data | ✅ Production |
| `profile_themes` | Profile customization | ✅ Production |
| `user_profile_settings` | User preferences | ✅ Production |
| `user_selected_title` | Selected title display | ✅ Production |
| `user_stats` | Aggregated user stats | ✅ Production |

## 🎮 **GAMES & ACHIEVEMENTS**
| Table | Purpose | Status |
|-------|---------|--------|
| `games` | Game catalog | ✅ Production |
| `achievements` | Cross-platform achievements | ✅ Production |
| `user_achievements` | Earned achievements | ✅ Production |
| `user_progress` | Per-game progress tracking | ✅ Production |
| `psn_user_trophy_profile` | PSN trophy levels/profile | ✅ Production |

## 🧾 **SYNC LOGS & LIMITING**
| Table | Purpose | Status |
|-------|---------|--------|
| `psn_sync_logs` | PSN sync tracking | ✅ Production |
| `xbox_sync_logs` | Xbox sync tracking | ✅ Production |
| `steam_sync_logs` | Steam sync tracking | ✅ Production |
| `user_sync_history` | Rate limiting + sync history | ✅ Production |

## 🏆 **LEADERBOARDS & CACHES**
| Table | Purpose | Status |
|-------|---------|--------|
| `leaderboard_cache` | StatusXP leaderboard cache | ✅ Production |

## 💰 **PREMIUM & AI**
| Table | Purpose | Status |
|-------|---------|--------|
| `user_premium_status` | Premium subscriptions | ✅ Production |
| `user_ai_credits` | AI guide credits | ✅ Production |
| `user_ai_daily_usage` | AI usage tracking | ✅ Production |
| `user_ai_pack_purchases` | Credit pack purchases | ✅ Production |

## 🧠 **META ACHIEVEMENTS**
| Table | Purpose | Status |
|-------|---------|--------|
| `meta_achievements` | Special achievements | ✅ Production |
| `user_meta_achievements` | Earned meta achievements | ✅ Production |

## 🧑‍🤝‍🧑 **SOCIAL & HELP**
| Table | Purpose | Status |
|-------|---------|--------|
| `achievement_comments` | Achievement comments | ✅ Production |
| `trophy_help_requests` | Help requests | ✅ Production |
| `trophy_help_responses` | Help responses | ✅ Production |

## 🎯 **GAME GROUPING**
| Table | Purpose | Status |
|-------|---------|--------|
| `game_groups` | Cross-platform matches | ✅ Production |
| `game_groups_refresh_queue` | Grouping refresh queue | ✅ Production |

## 🧩 **FEATURE TABLES**
| Table | Purpose | Status |
|-------|---------|--------|
| `flex_room_data` | Flex Room data | ✅ Production |
| `trophy_room_shelves` | Trophy room layout | ✅ Production |
| `trophy_room_items` | Trophy room items | ✅ Production |
| `display_case_items` | Display case data | ⚠️ Pending removal |

## 🧹 **CLEANUP CANDIDATES**
| Table | Reason | Action |
|-------|--------|--------|
| `display_case_items` | Feature removed from app | Drop via migration 20260125001000_drop_display_case_items.sql |

## ✅ **NOTES**
- V2 duplicate tables (games_v2, achievements_v2, etc.) are NOT present in DATABASE_SCHEMA_LIVE.sql.
- Older audit sections about v2 duplicates and completion_history/virtual_completions are obsolete in this repo snapshot.
