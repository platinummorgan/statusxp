# Release Notes - Version 1.0.0+30

## New Feature: Password Reset

### Password Recovery
- **"Forgot Password?" link** added to sign-in screen
- Users can now reset forgotten passwords via email
- Secure password reset flow using Supabase authentication
- Email sent with password reset link
- Clear confirmation when reset email is sent

### User Experience Improvements
- Simple, intuitive password reset interface
- Visual feedback with success confirmation screen
- Option to resend reset email if not received
- Matches app's StatusXP theme with neon accents

### Technical Implementation
- Integrated Supabase `resetPasswordForEmail()` API
- Deep link redirect: `com.platovalabs.statusxp://reset-password`
- Added `updatePassword()` method for password changes
- Proper error handling for failed requests

### Why This Update
A user reported forgetting their password with no way to recover access. This critical feature ensures users can always regain access to their accounts.

---

**Previous Update (1.0.0+29):** Code organization and cleanup

**Build:** 1.0.0+30 (December 30, 2025)  
**Type:** Feature release - Password reset functionality  
**Impact:** Users can now recover forgotten passwords
