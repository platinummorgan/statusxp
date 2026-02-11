# Fix Apple Sign-In for Web (statusxp.com)

## Current Error
```
invalid_request
Invalid client id or web redirect url
```

## Problem
Using iOS app bundle ID `com.statusxp.statusxp` for web sign-in, but web requires a Services ID.

## Fix Steps

### 1. Create Services ID (if not exists)
Go to [Apple Developer Console](https://developer.apple.com/account/resources/identifiers/list/serviceId)

1. Click **+** to create new identifier
2. Select **Services IDs**
3. Create identifier:
   - Description: `StatusXP Web`
   - Identifier: `com.statusxp.web` (or similar)
4. Click **Continue** and **Register**

### 2. Configure Services ID for Sign in with Apple
1. Click on your new Services ID
2. Enable **Sign in with Apple**
3. Click **Configure**
4. Set:
   - **Primary App ID**: Select your app ID (`com.statusxp.statusxp`)
   - **Website URLs**: Add domains and redirect URLs:
     - **Domains**: 
       - `statusxp.com`
       - `ksriqcmumjkemtfjuedm.supabase.co`
     - **Return URLs**:
       - `https://ksriqcmumjkemtfjuedm.supabase.co/auth/v1/callback`
5. Click **Save**, then **Continue**, then **Save**

### 3. Update Supabase Auth Provider Configuration
Go to [Supabase Dashboard > Authentication > Providers > Apple](https://supabase.com/dashboard/project/ksriqcmumjkemtfjuedm/auth/providers)

Update the **Services ID** field with your new Services ID:
- Current (wrong for web): `com.statusxp.statusxp`
- Should be: `com.statusxp.web`

**Important**: Keep the **Bundle ID** as `com.statusxp.statusxp` (that's for iOS app)

### 4. Verify Configuration
The auth URL should use the Services ID as client_id:
```
https://appleid.apple.com/auth/authorize?
  client_id=com.statusxp.web  <-- Services ID, not bundle ID
  &redirect_uri=https://ksriqcmumjkemtfjuedm.supabase.co/auth/v1/callback
```

## Notes
- iOS app continues using `com.statusxp.statusxp` (bundle ID)
- Web must use the Services ID (`com.statusxp.web`)
- Both point to the same Primary App ID in Apple's configuration
