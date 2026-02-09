# Patch Plan: Active Runtime

Generated: 2026-02-09
Objective: remove active schema/runtime drift with lowest regression risk.

## Already Applied (This Pass)
- Premium expiry column normalized to premium_expires_at in active premium handlers.
- Subscription activation no longer fails if notifications insert is unavailable.
- Legacy backup/alternate runtime files moved to legacy/.

## Phase 1 (Low Risk, Next)
- Add migration for notifications table if it is intended to exist.
- If notifications is intentionally optional, add shared safe-notify wrappers in edge functions.
- Update delete-account to skip/guard missing legacy tables (user_ai_guides, user_trophies).

## Phase 2 (Medium Risk)
- Replace app repository usage of trophies/user_trophies with achievements/user_achievements model.
- Refactor TrophyList/TrophyRoom data mapping to platform_id + platform_game_id + platform_achievement_id keys.
- Validate Games List drill-in and Trophy Room views against real PSN/Xbox/Steam data.

## Phase 3 (Hardening)
- Add CI checks that compare lib/.from() and active edge .from() against latest dumped schema.
- Add a periodic command to regenerate Reality2.9.26 and DatabaseSchema2.9.26 style reports with date-based names.

## Files Most Likely to Change in Phase 1
- lib/services/subscription_service.dart (completed for premium activation path)
- supabase/functions/stripe-webhook/index.ts
- supabase/functions/twitch-eventsub-webhook/index.ts
- supabase/functions/twitch-link-account/index.ts
- supabase/functions/twitch-check-expiring-premium/index.ts
- supabase/functions/twitch-check-subscription/index.ts
- supabase/functions/delete-account/index.ts

