# Active-Only Mismatch Report

Generated: 2026-02-09
Source schema: `sql_archive/DATABASE_SCHEMA_LIVE_2026-02-09.sql`
Compat delta included: all files in `supabase/migrations/*.sql`

## Runtime Scope Included
- Flutter runtime files under `lib/`
- Active edge function entrypoints `supabase/functions/*/index.ts`
- `sync-service/index.js` API surface

## Runtime Scope Excluded
- `legacy/` archive files
- `index-old/index-clean/index-backup` files
- one-off backfill/admin helper scripts

## Active Runtime Objects Missing From Schema
- None

## Active Runtime Reference Lines (Missing Objects Only)
- None
## Notes
- Missing objects here are code references not found in the schema dump plus compat migration text.
- This report does not assert runtime failure by itself; some references may be behind guarded code paths.

