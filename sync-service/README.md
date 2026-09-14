# StatusXP Sync Service

Background sync service for Xbox, Steam, and PSN achievement data.

## Deploy to Railway

Before deploying the leaderboard retry worker, manually apply
`supabase/migrations/20260911140000_leaderboard_refresh_jobs.sql` using the
project's migration process. Do not run `supabase db push --linked`.
The worker requires this queue schema. See
[refresh queue release notes](../docs/reviews/2026-09-11/IMPLEMENTATION_05.md)
for verification, retry behavior, and the existing trigger-removal migration.

1. Push this folder to GitHub
2. In Railway dashboard:
   - Click "New Project" → "Deploy from GitHub repo"
   - Select this repo
   - Set root directory to `sync-service`
   - Set Config-as-Code file path to `/sync-service/railway.json`
   - Clear any custom build command (do not use `bash build.sh` for this service)
   - Add environment variables:
     - `SUPABASE_URL`
     - `SUPABASE_SERVICE_ROLE_KEY`
     - `SYNC_SERVICE_SECRET` (must match the Supabase Edge Function secret)
     - `STEAM_WEB_API_KEY` (shared Steam Web API key for all Steam syncs)
3. Deploy!

## Environment Variables

- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Your Supabase service role key
- `SYNC_SERVICE_SECRET` - Required for startup in every environment. Protected routes require `Authorization: Bearer <secret>`. Use the same value in the calling Edge Functions; health endpoints remain public. Never put this value in a Flutter build or client configuration.
- `STEAM_WEB_API_KEY` - Shared Steam Web API key used by Steam sync
- `PORT` - Automatically set by Railway

## Endpoints

- `GET /` - Health check
- `POST /sync/xbox` - Start Xbox sync
- `POST /admin/xbox/backfill-rarity` - Backfill Xbox rarity without user sync (requires `SYNC_SERVICE_SECRET`)

### Admin Backfill

Request body (optional):
```
{
  "limitTitles": 50,
  "dryRun": false
}
```

Required env vars:
- `OPENXBL_API_KEY`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
