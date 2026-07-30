# Store purchase verification setup

StatusXP verifies Google Play and App Store purchases in the
`verify-store-purchase` Supabase Edge Function. Purchases are not acknowledged
by the app until verification and entitlement delivery both succeed.

## Google Play

1. Create or select a Google Cloud service account.
2. Grant it access to StatusXP in Play Console with permission to view orders
   and manage subscriptions.
3. Enable the Google Play Android Developer API for its Cloud project.
4. Store the complete service-account JSON as a Supabase secret:

   ```powershell
   supabase secrets set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON='<single-line JSON>'
   ```

## App Store

Create an App Store Connect API key with in-app-purchase access, then configure:

```powershell
supabase secrets set APPLE_APP_STORE_ISSUER_ID='<issuer UUID>'
supabase secrets set APPLE_APP_STORE_KEY_ID='<key ID>'
supabase secrets set APPLE_APP_STORE_PRIVATE_KEY='<contents of the .p8 file>'
```

## Deploy

Apply the database migration before deploying the function:

```powershell
supabase db push
supabase functions deploy verify-store-purchase
```

Test purchases through a Play license-testing account and an App Store sandbox
account before promoting a mobile release.
