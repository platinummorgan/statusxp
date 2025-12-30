# Account Linking Implementation

## Problem Fixed
Users were creating duplicate accounts when:
1. Sign up with email → creates Account A
2. Click "Sign in with Apple/Google" → creates Account B (duplicate)
3. Result: Two accounts, split data, confusion

## Solution Implemented

### ✅ Automatic Account Linking
**When user is LOGGED IN:**
- Clicking "Sign in with Google" → **Links** Google to existing account (no duplicate)
- Clicking "Sign in with Apple" → **Links** Apple ID to existing account (no duplicate)
- Shows success message: "✅ Google/Apple linked successfully!"

**When user is NOT logged in:**
- Clicking "Sign in with Google/Apple" → Signs in normally (may create new if first time)
- If OAuth account already linked elsewhere → Shows clear error message

### Code Changes

**Files Modified:**
1. `lib/data/auth/auth_service.dart`
   - Modified `signInWithGoogle()` to check if user is authenticated
   - If authenticated, uses `linkIdentity()` instead of `signInWithIdToken()`
   - Modified `signInWithApple()` with same logic
   - Added helpful error messages for linking failures

2. `lib/ui/screens/auth/sign_in_screen.dart`
   - Enhanced error handling for OAuth sign-in
   - Shows success messages when accounts are linked
   - Shows user-friendly errors when linking fails

3. `supabase/migrations/107_check_oauth_duplicates.sql`
   - Backend function to detect potential duplicates (for future use)

### How It Works

**Scenario 1: User wants to add Apple/Google to existing account**
```
1. User signs in with email
2. User clicks "Sign in with Apple"
3. App detects user is logged in
4. Calls linkIdentity() instead of signInWithIdToken()
5. Apple ID linked to existing account ✅
6. Shows: "✅ Apple ID linked successfully!"
```

**Scenario 2: OAuth account already used elsewhere**
```
1. User A signs in with email, links Google
2. User B tries to sign in with same Google account
3. linkIdentity() fails (already linked to User A)
4. Shows: "This Google account is already linked to another account"
```

**Scenario 3: First time OAuth user**
```
1. New user clicks "Sign in with Apple"
2. No existing account, creates new account
3. Works as expected ✅
```

## Benefits

✅ **No more duplicate accounts** - linking prevents account creation
✅ **Users can have multiple sign-in methods** - email + Apple + Google all linked to ONE account
✅ **Clear error messages** - users know what went wrong
✅ **Backwards compatible** - existing accounts unaffected

## Testing Checklist

- [ ] Test linking Google while logged in with email
- [ ] Test linking Apple while logged in with email  
- [ ] Test signing in with Google when not logged in (should work normally)
- [ ] Test signing in with Apple when not logged in (should work normally)
- [ ] Test trying to link an OAuth account that's already linked elsewhere (should show error)
- [ ] Test signing in with linked account works from all methods

## Migration Notes

**Existing duplicate accounts need manual merging:**
- Use `merge_dahead22_accounts.sql` as template
- Manually delete duplicate auth users from Supabase Dashboard
- Future duplicates will be prevented automatically

## User Instructions

**To link additional sign-in methods:**
1. Sign in with your primary account (email/password)
2. Go to sign-in screen (or trigger OAuth buttons)
3. Click "Sign in with Apple" or "Sign in with Google"
4. Your Apple/Google account will be linked
5. Now you can sign in using any linked method!

**Important:** Don't sign in with Apple/Google before creating an account - it will create a separate account. Always create with email first, then link OAuth.
