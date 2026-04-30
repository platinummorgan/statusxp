# StatusXP Sync Service

Background sync service for Xbox, Steam, and PSN achievement data.

## Deploy to Railway

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
3. Deploy!

## Environment Variables

- `SUPABASE_URL` - Your Supabase project URL
- `SUPABASE_SERVICE_ROLE_KEY` - Your Supabase service role key
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
