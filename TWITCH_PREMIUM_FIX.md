# Twitch Premium Issue Diagnosis

## Problem
You have numerous Twitch subscribers, but only you show as premium in StatusXP.

## Root Cause
**EventSub webhooks are not registered with Twitch.** 

The system relies on Twitch sending webhook notifications when users:
- Subscribe to your channel
- Renew their subscription
- Cancel their subscription

Without these webhooks, StatusXP never knows when someone subscribes.

## How It's Supposed to Work

1. User links their Twitch account on StatusXP website
2. Their `twitch_user_id` is saved in the database
3. When they subscribe on Twitch, Twitch sends a webhook to StatusXP
4. StatusXP looks up the user by `twitch_user_id` and grants premium

**Your case:** Steps 1-2 work, but step 3 never happens because webhooks aren't registered.

## Solution

### Step 1: Verify EventSub Subscriptions

Check if webhooks are registered:

```bash
# Install Twitch CLI if you haven't:
# Windows: scoop install twitch-cli
# Or: https://github.com/twitchdev/twitch-cli

# Then authenticate:
twitch configure

# List current EventSub subscriptions
twitch api get eventsub/subscriptions
```

You should see 3 subscriptions:
- `channel.subscribe`
- `channel.subscription.end`
- `channel.subscription.message`

If you see **0 subscriptions**, that's your problem!

### Step 2: Register EventSub Webhooks

```bash
# Get your Supabase project URL
# Format: https://ksriqcmumjkemtfjuedm.supabase.co

# Get your broadcaster ID (your Twitch user ID)
twitch api get users -q login=YOUR_TWITCH_USERNAME

# Get your TWITCH_EVENTSUB_SECRET from Supabase secrets
# (You set this in Supabase Dashboard → Edge Functions → Secrets)

# Register channel.subscribe
twitch api post eventsub/subscriptions -b '{
  "type": "channel.subscribe",
  "version": "1",
  "condition": {
    "broadcaster_user_id": "YOUR_BROADCASTER_ID"
  },
  "transport": {
    "method": "webhook",
    "callback": "https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-eventsub-webhook",
    "secret": "YOUR_EVENTSUB_SECRET"
  }
}'

# Register channel.subscription.message (renewals)
twitch api post eventsub/subscriptions -b '{
  "type": "channel.subscription.message",
  "version": "1",
  "condition": {
    "broadcaster_user_id": "YOUR_BROADCASTER_ID"
  },
  "transport": {
    "method": "webhook",
    "callback": "https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-eventsub-webhook",
    "secret": "YOUR_EVENTSUB_SECRET"
  }
}'

# Register channel.subscription.end
twitch api post eventsub/subscriptions -b '{
  "type": "channel.subscription.end",
  "version": "1",
  "condition": {
    "broadcaster_user_id": "YOUR_BROADCASTER_ID"
  },
  "transport": {
    "method": "webhook",
    "callback": "https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-eventsub-webhook",
    "secret": "YOUR_EVENTSUB_SECRET"
  }
}'
```

### Step 3: Deploy Backfill Function

I've created a function to manually check ALL users with linked Twitch accounts:

```bash
cd d:\Dev\statusxp\supabase
npx supabase functions deploy twitch-backfill-subscribers
```

### Step 4: Run Backfill

```bash
# Get your SUPABASE_SERVICE_ROLE_KEY from Supabase Dashboard → Settings → API

curl -X POST 'https://ksriqcmumjkemtfjuedm.supabase.co/functions/v1/twitch-backfill-subscribers' \
  -H 'Authorization: Bearer YOUR_SERVICE_ROLE_KEY'
```

This will:
- Check every user with a linked Twitch account
- Query Twitch API to see if they're subscribed
- Grant premium if subscribed
- Revoke premium if not subscribed (only if source was Twitch)

### Step 5: Verify Results

Run the SQL query to see updated status:

```sql
SELECT 
  p.id,
  au.email,
  p.twitch_user_id,
  ups.is_premium,
  ups.premium_source,
  ups.expires_at,
  ups.updated_at
FROM profiles p
LEFT JOIN auth.users au ON au.id = p.id
LEFT JOIN user_premium_status ups ON ups.user_id = p.id
WHERE p.twitch_user_id IS NOT NULL
ORDER BY ups.is_premium DESC, p.created_at DESC;
```

## Important Notes

### Users Must Link Their Accounts

**Critical:** Users can only get premium if they've linked their Twitch account to StatusXP.

The system cannot automatically detect subscribers - users must:
1. Visit StatusXP website (not mobile app)
2. Go to account settings
3. Click "Connect Twitch"
4. Complete OAuth flow

Only AFTER linking can the webhook system grant them premium.

### Why Only You Have Premium

You probably:
1. Linked your Twitch account manually
2. Ran the manual check function (`twitch-check-subscription`)
3. Or the system detected you as the broadcaster and granted premium

Your subscribers likely haven't linked their accounts yet.

### Premium Hierarchy

If a user has multiple premium sources, the system respects this hierarchy:
1. **Apple/Google IAP** (highest - never overwritten)
2. **Stripe** (direct payment)
3. **Twitch** (lowest)

If someone has Stripe premium and then subscribes on Twitch, Twitch won't overwrite it.

### Grace Period

Twitch premium includes a 3-day grace period:
- Subscription lasts 30 days
- Grace period adds 3 more days (33 days total)
- If they re-subscribe during grace period, time is added to existing expiry

## Test the Fix

After registering webhooks and running backfill:

1. Have a test user link their Twitch account
2. Subscribe to your channel (can use test subscription in Twitch dev console)
3. Check `user_premium_status` table - should show premium within seconds
4. Unsubscribe - should revoke after grace period expires

## Monitoring

Check webhook logs in Supabase:
```bash
# View logs for webhook function
npx supabase functions logs twitch-eventsub-webhook
```

Should see entries like:
```
📬 Received channel.subscribe for user USERNAME (12345678)
🎁 New subscription: USERNAME (Tier 1000)
✅ Premium granted to user abc-123-def
```

If you see no logs when subscriptions happen, webhooks aren't registered correctly.
