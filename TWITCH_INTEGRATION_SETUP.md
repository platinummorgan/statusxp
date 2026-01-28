# Twitch Integration Setup Guide

## Overview

Twitch subscribers can get premium StatusXP access automatically through subscription linking.

## Architecture

- **Web-only** Twitch account linking (no mobile app changes needed)
- Server-side subscription verification via Twitch API
- EventSub webhooks for real-time subscription status updates
- Mobile apps automatically see premium access (reads from `user_premium_status`)

## Setup Steps

### 1. Create Twitch Application

1. Go to https://dev.twitch.tv/console/apps
2. Click "Register Your Application"
3. Fill in details:
   - **Name**: StatusXP
   - **OAuth Redirect URLs**: 
     - `https://your-domain.com/twitch/callback`
     - `http://localhost:3000/twitch/callback` (for testing)
   - **Category**: Website Integration
4. Save and note your **Client ID** and **Client Secret**

### 2. Get Broadcaster ID

Your Twitch broadcaster ID (your channel's user ID):

```bash
# Using Twitch CLI
twitch api get users -q login=your_channel_name

# Or via API with app access token
curl -X GET 'https://api.twitch.tv/helix/users?login=your_channel_name' \
  -H 'Authorization: Bearer YOUR_APP_TOKEN' \
  -H 'Client-Id: YOUR_CLIENT_ID'
```

### 3. Configure Supabase Secrets

Add these secrets to your Supabase project:

```bash
# Required
TWITCH_CLIENT_ID=your_client_id_here
TWITCH_CLIENT_SECRET=your_client_secret_here
TWITCH_BROADCASTER_ID=your_broadcaster_id_here

# EventSub webhook secret (create a random string)
TWITCH_EVENTSUB_SECRET=generate_random_string_here
```

### 4. Deploy Edge Functions

```bash
# Deploy all Twitch functions
supabase functions deploy twitch-link-account
supabase functions deploy twitch-check-subscription
supabase functions deploy twitch-eventsub-webhook

# Set secrets
supabase secrets set TWITCH_CLIENT_ID=xxx TWITCH_CLIENT_SECRET=xxx TWITCH_BROADCASTER_ID=xxx TWITCH_EVENTSUB_SECRET=xxx
```

### 5. Run Database Migration

```bash
# Apply migration to add twitch_user_id column
supabase db push
```

Or manually run:
```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS twitch_user_id TEXT;
CREATE INDEX IF NOT EXISTS idx_profiles_twitch_user_id ON profiles(twitch_user_id) WHERE twitch_user_id IS NOT NULL;
```

### 6. Register EventSub Subscriptions

Use Twitch CLI or API to register webhooks:

```bash
# Install Twitch CLI: https://github.com/twitchdev/twitch-cli

# Subscribe to channel.subscribe events
twitch api post eventsub/subscriptions -b '{
  "type": "channel.subscribe",
  "version": "1",
  "condition": {
    "broadcaster_user_id": "YOUR_BROADCASTER_ID"
  },
  "transport": {
    "method": "webhook",
    "callback": "https://your-project.supabase.co/functions/v1/twitch-eventsub-webhook",
    "secret": "YOUR_EVENTSUB_SECRET"
  }
}'

# Subscribe to channel.subscription.end events
twitch api post eventsub/subscriptions -b '{
  "type": "channel.subscription.end",
  "version": "1",
  "condition": {
    "broadcaster_user_id": "YOUR_BROADCASTER_ID"
  },
  "transport": {
    "method": "webhook",
    "callback": "https://your-project.supabase.co/functions/v1/twitch-eventsub-webhook",
    "secret": "YOUR_EVENTSUB_SECRET"
  }
}'

# Subscribe to channel.subscription.gift events
twitch api post eventsub/subscriptions -b '{
  "type": "channel.subscription.gift",
  "version": "1",
  "condition": {
    "broadcaster_user_id": "YOUR_BROADCASTER_ID"
  },
  "transport": {
    "method": "webhook",
    "callback": "https://your-project.supabase.co/functions/v1/twitch-eventsub-webhook",
    "secret": "YOUR_EVENTSUB_SECRET"
  }
}'
```

## Web Implementation (TODO)

Create a web page for linking Twitch accounts:

### React/Next.js Example

```typescript
// pages/connect/twitch.tsx
import { useState } from 'react';
import { supabase } from '@/lib/supabase';

export default function ConnectTwitch() {
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleConnect = () => {
    const clientId = process.env.NEXT_PUBLIC_TWITCH_CLIENT_ID;
    const redirectUri = `${window.location.origin}/twitch/callback`;
    const scope = 'user:read:subscriptions';
    
    const authUrl = `https://id.twitch.tv/oauth2/authorize?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=${scope}`;
    
    window.location.href = authUrl;
  };

  return (
    <div className="max-w-md mx-auto p-6">
      <h1 className="text-2xl font-bold mb-4">Connect Your Twitch Account</h1>
      
      <p className="mb-6">
        Link your Twitch account to automatically get premium access when you subscribe!
      </p>

      {error && (
        <div className="bg-red-100 text-red-700 p-4 rounded mb-4">
          {error}
        </div>
      )}

      <button
        onClick={handleConnect}
        disabled={loading}
        className="w-full bg-purple-600 text-white py-3 px-6 rounded-lg hover:bg-purple-700"
      >
        {loading ? 'Connecting...' : 'Connect with Twitch'}
      </button>

      <p className="text-sm text-gray-600 mt-4">
        💡 Tip: Twitch subscribers ($4.99/month) automatically get StatusXP Premium access!
      </p>
    </div>
  );
}
```

```typescript
// pages/twitch/callback.tsx
import { useEffect, useState } from 'react';
import { useRouter } from 'next/router';
import { supabase } from '@/lib/supabase';

export default function TwitchCallback() {
  const router = useRouter();
  const [status, setStatus] = useState('Processing...');

  useEffect(() => {
    const handleCallback = async () => {
      const { code } = router.query;
      
      if (!code) {
        setStatus('Error: No authorization code received');
        return;
      }

      try {
        const redirectUri = `${window.location.origin}/twitch/callback`;
        
        const { data, error } = await supabase.functions.invoke('twitch-link-account', {
          body: { code, redirectUri },
        });

        if (error) throw error;

        if (data.isSubscribed) {
          setStatus('✅ Success! Your Twitch subscription unlocked premium access!');
        } else {
          setStatus('✅ Twitch account linked! Subscribe to unlock premium access.');
        }

        setTimeout(() => router.push('/dashboard'), 2000);
      } catch (error) {
        console.error('Error linking Twitch:', error);
        setStatus(`Error: ${error.message}`);
      }
    };

    if (router.isReady) {
      handleCallback();
    }
  }, [router]);

  return (
    <div className="max-w-md mx-auto p-6 text-center">
      <h1 className="text-2xl font-bold mb-4">{status}</h1>
    </div>
  );
}
```

## Testing

### Test Subscription Check

```bash
# Get user's JWT token from browser console
# localStorage.getItem('supabase.auth.token')

curl -X POST 'https://your-project.supabase.co/functions/v1/twitch-check-subscription' \
  -H 'Authorization: Bearer USER_JWT_TOKEN' \
  -H 'Content-Type: application/json'
```

### Test EventSub Webhook Locally

Use Twitch CLI to forward events:

```bash
twitch event trigger subscribe -F https://localhost:54321/functions/v1/twitch-eventsub-webhook
```

## How It Works

### User Flow

1. User visits web dashboard
2. Clicks "Connect Twitch"
3. OAuth flow → Twitch login
4. Callback receives code
5. Edge function:
   - Exchanges code for token
   - Gets Twitch user ID
   - Checks subscription status
   - Links account (`twitch_user_id` saved)
   - Grants premium if subscribed

### Subscription Updates

**When user subscribes:**
- Twitch sends EventSub webhook → `channel.subscribe`
- Edge function finds user by `twitch_user_id`
- Updates `user_premium_status` → grants premium

**When subscription ends:**
- Twitch sends EventSub webhook → `channel.subscription.end`
- Edge function finds user by `twitch_user_id`
- Updates `user_premium_status` → revokes premium (only if source was Twitch)

### Mobile App Behavior

**No changes needed!** Mobile app already:
- Reads `user_premium_status` table
- Shows premium features if `is_premium = true`
- Doesn't care about payment source

## Compliance Notes

✅ **Allowed:**
- Web page promotes Twitch subscriptions
- Server checks subscription status
- Mobile apps read server-side premium flag

❌ **Not allowed:**
- Buttons in iOS/Android app linking to Twitch subscriptions
- Mentioning external payment methods in mobile apps

This follows the same pattern as Stripe web subscriptions - external payment, server-side flag, mobile reads flag.

## Environment Variables Summary

```bash
# Supabase Secrets (set via `supabase secrets set`)
TWITCH_CLIENT_ID=xxx
TWITCH_CLIENT_SECRET=xxx
TWITCH_BROADCASTER_ID=xxx
TWITCH_EVENTSUB_SECRET=xxx

# Web App .env (Next.js example)
NEXT_PUBLIC_TWITCH_CLIENT_ID=xxx
NEXT_PUBLIC_SUPABASE_URL=xxx
NEXT_PUBLIC_SUPABASE_ANON_KEY=xxx
```

## Troubleshooting

**"Twitch credentials not configured"**
- Check Supabase secrets are set correctly
- Verify Edge Functions can access secrets

**"No StatusXP user found with Twitch ID"**
- User hasn't linked their Twitch account yet
- They need to visit web dashboard and connect

**EventSub webhook not receiving events**
- Verify webhook URL is publicly accessible
- Check EventSub subscriptions are active: `twitch api get eventsub/subscriptions`
- Verify signature secret matches

**Subscription check returns false but user is subscribed**
- Check `TWITCH_BROADCASTER_ID` is correct
- Verify user is actually subscribed (not just followed)
- Test with Twitch CLI: `twitch api get subscriptions/user`
