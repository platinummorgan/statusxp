# Game Cover Backfill Instructions (SQL + Edge Function)

## The Problem
PlayStation and Xbox game cover images have CORS restrictions that prevent them from loading on web. Steam is fine.

## The Solution
Download images from PlayStation/Xbox CDNs and upload to Supabase Storage (which has CORS enabled).

## Steps to Run:

### 1. Run SQL in Supabase Dashboard
Open `run_backfill_steps.sql` and run each query:
- Check scope (how many games need fixing)
- Create storage bucket
- Set storage policies

### 2. Deploy ONLY the backfill function
```powershell
cd supabase/functions/backfill-game-covers
npx supabase functions deploy backfill-game-covers
```
This deploys ONLY this function, won't affect your migrations/sync.

### 3. Run the backfill via curl

Get your service role key from: https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/settings/api

**For PlayStation (batch 1):**
```powershell
curl -X POST https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/backfill-game-covers -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" -H "Content-Type: application/json" -d '{\"platform_ids\": [1, 2, 5, 9], \"batch_size\": 50, \"offset\": 0}'
```

**For PlayStation (batch 2):**
```powershell
curl -X POST https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/backfill-game-covers -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" -H "Content-Type: application/json" -d '{\"platform_ids\": [1, 2, 5, 9], \"batch_size\": 50, \"offset\": 50}'
```

Repeat, incrementing offset by 50 until all PlayStation games are done.

**For Xbox:**
```powershell
curl -X POST https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/backfill-game-covers -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" -H "Content-Type: application/json" -d '{\"platform_ids\": [10, 11, 12], \"batch_size\": 50, \"offset\": 0}'
```

Repeat with offsets 50, 100, 150, etc.

### 4. Verify
Run the last query in `run_backfill_steps.sql` to see how many games now have Supabase URLs.

## No database sync needed!
- Edge function is separate from migrations
- SQL runs directly in dashboard
- No git changes needed
