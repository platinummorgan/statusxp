# Demo Tester Account Setup

## Quick Setup (3 Steps)

### Step 1: Create Demo User in Supabase
1. Go to Supabase Dashboard → Authentication → Users
2. Click **"Add user"** → **"Create new user"**
3. Email: `demo@statusxp.test`
4. Password: `StatusXP2025!`
5. Click **"Create user"**

### Step 2: Update SQL with Your User ID
1. Find your user ID by running in Supabase SQL Editor:
   ```sql
   SELECT id, email FROM auth.users WHERE email = 'your-actual-email@example.com';
   ```
2. Copy your user ID
3. Open `create_demo_tester_account.sql`
4. Replace line 15: `v_source_user_id UUID := 'YOUR_USER_ID_HERE';`
5. Paste your actual user ID

### Step 3: Run the Migration
1. Go to Supabase → SQL Editor
2. Copy/paste entire contents of `create_demo_tester_account.sql`
3. Click **"Run"**
4. Wait for success messages

## What Gets Created

✅ **Profile**: DemoTester with PS Plus badge  
✅ **Games**: Your top 10 best completed games  
✅ **Achievements**: All achievements from those 10 games  
✅ **AI Credits**: 10 pack credits for testing  
✅ **Flex Room**: Copy of your showcase  
✅ **Premium**: Set to FREE (you can change to TRUE for premium testing)

## Demo Account Credentials

**Share these with your testers:**

📧 **Email**: `demo@statusxp.test`  
🔒 **Password**: `StatusXP2025!`

## Tester Instructions

Share this with your testers community:

---

### How to Test StatusXP

1. **Download & Install** the app from the testing link
2. **Sign in** with:
   - Email: `demo@statusxp.test`
   - Password: `StatusXP2025!`
3. **Explore**:
   - Dashboard (see cross-platform stats)
   - Games list (10 pre-loaded games)
   - Individual games (tap to see achievements)
   - Flex Room (curated showcase)
   - AI Help (10 free credits to test guides)
   - Settings (try Support Development, view legal docs)

**Note**: This is a demo account with pre-loaded data. You don't need your own PlayStation/Xbox/Steam accounts to test the app!

---

## Optional: Enable Premium Testing

If you want testers to see premium features:

1. Run in Supabase SQL Editor:
   ```sql
   UPDATE user_premium_status 
   SET is_premium = true, premium_since = NOW()
   WHERE user_id = (SELECT id FROM auth.users WHERE email = 'demo@statusxp.test');
   ```

2. Testers will now see:
   - Unlimited AI guides
   - Faster sync cooldowns
   - Premium badge

## Troubleshooting

**Demo user can't sign in?**
- Check user exists in Supabase Auth
- Verify email/password are correct
- Check user is not disabled

**No data showing?**
- Verify Step 2 used your correct user ID
- Check SQL ran successfully (look for success messages)
- Run the verification query at bottom of SQL file

**Need to reset demo data?**
- Just run the SQL script again - it will overwrite
