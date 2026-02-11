# Apple Auth Secret Rotation Runbook (StatusXP)

This runbook documents the exact steps to rotate Apple OAuth credentials for StatusXP.

## Current production values
- Supabase project ref: `ksriqcmumjkemtfjuedm`
- Supabase callback URL: `https://ksriqcmumjkemtfjuedm.supabase.co/auth/v1/callback`
- Web Apple client ID (Services ID): `com.statusxp.statusxp.signin`
- iOS bundle ID client ID: `com.statusxp.statusxp`
- Team ID: `4WBYD78AZD`

## When to rotate
- Apple OAuth client secrets expire every 6 months.
- Rotate at least 7 days before expiration.

## Files/tools in this repo
- Generator script: `scripts/generate_apple_client_secret.py`

## Step 1: Create or locate Apple Sign In key
In Apple Developer:
1. Go to `Certificates, Identifiers & Profiles` -> `Keys`.
2. Create a new key with **Sign in with Apple** enabled (if needed).
3. Download `AuthKey_<KEY_ID>.p8` (download is one-time only).
4. Store `.p8` in secure storage (password manager vault / secure drive). Do not commit it.

## Step 2: Generate client secret JWT
Run locally:

```powershell
python scripts/generate_apple_client_secret.py `
  --team-id 4WBYD78AZD `
  --key-id <KEY_ID> `
  --client-id com.statusxp.statusxp.signin `
  --p8-path "C:\path\to\AuthKey_<KEY_ID>.p8"
```

The script prints:
- JWT client secret (paste into Supabase)
- Expiration timestamp (UTC)

## Step 3: Update Supabase Apple provider
Supabase Dashboard -> `Authentication` -> `Providers` -> `Apple`:
1. Enable Apple provider.
2. Set `Client IDs` to:
   - `com.statusxp.statusxp.signin`
   - If needed for native flows: `,com.statusxp.statusxp`
3. Paste JWT into `Secret Key (for OAuth)`.
4. Save.

## Step 4: Validate
1. Web test (incognito): `https://statusxp.com` -> `Continue with Apple`.
2. Confirm successful redirect/login (no callback error page).
3. Mobile test: Apple account linking in Settings.
4. Check Supabase Auth logs for no `invalid_client`/`server_error`.

## Common failure signatures
- `oauth2: "invalid_client"`:
  - wrong client ID in secret (`sub`)
  - wrong key ID / team ID
  - old/revoked key
- `Unable to exchange external code`:
  - upstream Apple credential mismatch (same root cause as above).

## Operational notes
- Keep only active keys in Apple Developer to reduce confusion.
- After new key is confirmed working, revoke old unused key.
- Track secret expiry in calendar with reminder.
