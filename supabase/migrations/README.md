# StatusXP Database Migrations Strategy

## Current Approach: Manual SQL Execution

We run SQL changes directly in the Supabase SQL Editor for production. Migration files are kept for:
- Documentation/reference
- Version control history
- Local development environments (if needed)

## DO NOT RUN: `supabase db push --linked`

This will attempt to re-apply migrations that were manually run, causing:
- Duplicate key errors
- Lost data (overwriting newer schema changes)
- Database corruption

## Production Workflow

1. **Write SQL directly** - Create `.sql` files locally for reference
2. **Test in Supabase SQL Editor** - Run on production database directly
3. **Commit SQL file** - Keep in version control for documentation
4. **Archive migration files** - Move to `_manual_production_archive/` so they don't confuse Supabase CLI

## Active Migrations

Only these migrations are tracked as "active":
- `20260121213830_baseline_from_live.sql` - Initial baseline from production
- `20260206000001_create_activity_feed_tables.sql` - Activity feed feature
- `20260207000001_fix_leaderboard_display_names.sql` - Leaderboard display name fix (manually applied)

## Archive Folders

- `_archive_old_migrations/` - Very old migrations from initial development
- `_manual_production_archive/` - Migrations that were manually applied to production (2026+)

## If You Need Proper Migrations

If you want to switch to proper migration management:
1. Pull current schema: `supabase db pull`
2. Delete all migration files except baseline
3. Create new baseline from pulled schema
4. Going forward: Create migrations with `supabase migration new <name>`, apply with `supabase db push`
