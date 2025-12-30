# Google Play Console - Product Setup for StatusXP

## 📦 Product IDs to Create (ALL IMPLEMENTED & READY)

### 1. Premium Subscription

**Product ID:** `statusxp_premium_monthly`

**Product Type:** Auto-renewing Subscription

**Product Name:** StatusXP Premium

**Description:** Monthly Subscription

**Subscription Period:** 1 month (Monthly)

**Price:** $4.99 USD

**Free Trial:** 7 days (recommended)

**Grace Period:** 3 days (recommended)

---

### 2. AI Credit Packs (Consumables)

These are NOW FULLY IMPLEMENTED. Create all three:

#### AI Pack Small
**Product ID:** `statusxp_ai_pack_small`

**Product Type:** Consumable (one-time purchase)

**Product Name:** AI Pack S

**Description:** 20 AI Achievement Guides

**Price:** $1.99 USD

---

#### AI Pack Medium
**Product ID:** `statusxp_ai_pack_medium`

**Product Type:** Consumable (one-time purchase)

**Product Name:** AI Pack M

**Description:** 60 AI Achievement Guides (Best Value!)

**Price:** $4.99 USD

---

#### AI Pack Large
**Product ID:** `statusxp_ai_pack_large`

**Product Type:** Consumable (one-time purchase)

**Product Name:** AI Pack L

**Description:** 150 AI Achievement Guides

**Price:** $9.99 USD

---

## 🎯 Features Included in Products

### Premium Subscription Features:

- ∞ **Unlimited AI Achievement Guides**
- ⚡ **Faster Sync Cooldowns**
- 🎯 **12 PSN syncs/day** (vs 3 free)
- ⏱️ **30min PSN cooldown** (vs 2hr free)
- 🎮 **15min Xbox/Steam cooldown** (vs 1hr free)
- 💎 **Premium Badge**
- 🚀 **Priority Support**
- ❤️ **Support Development**

### AI Credit Packs:

Free users get 3 AI guides per day. Packs provide additional uses:
- **Small Pack:** 20 AI uses for $1.99 (~10¢ per use)
- **Medium Pack:** 60 AI uses for $4.99 (~8¢ per use) - Best Value!
- **Large Pack:** 150 AI uses for $9.99 (~7¢ per use)

*Note: Premium subscribers get unlimited AI guides, so they don't need to buy packs.*

---

## 📝 Step-by-Step Google Play Console Setup

### 1. Go to Google Play Console
- Log in to: https://play.google.com/console
- Select your app: **StatusXP**

### 2. Navigate to Monetization Setup
- Left sidebar → **Monetize**
- Click **Products** → **Subscriptions**

### 3. Create New Subscription
Click **Create subscription** button

### 4. Fill in Product Details

**Basic Information:**
- **Product ID:** `statusxp_premium_monthly` ⚠️ MUST match exactly (cannot be changed later!)
- **Name:** StatusXP Premium
- **Description:** Unlock unlimited AI guides, faster syncs, premium badge, and priority support

**Subscription Period:**
- **Base Plan ID:** monthly-subscription
- **Billing Period:** 1 month
- **Price:** $4.99 USD (set pricing for all countries)

**Free Trial (Optional but Recommended):**
- **Enable Free Trial:** Yes
- **Trial Period:** 7 days
- **Eligibility:** New subscribers only

**Grace Period (Recommended):**
- **Enable Grace Period:** Yes
- **Duration:** 3 days
- **Purpose:** Allows users to fix payment issues without losing access

**Account Hold:**
- **Enable:** Yes (default)
- **Purpose:** Pauses subscription if payment fails

### 5. Save and Activate
- Click **Save**
- Click **Activate** to make it available

---

## ⚠️ Important Notes

1. **Product ID is PERMANENT** - Once created, `statusxp_premium_monthly` cannot be changed. Make sure it's correct!

2. **Testing First:**
   - Before activating, add test accounts in **Settings** → **License Testing**
   - Test the purchase flow thoroughly
   - Verify your app can detect the subscription

3. **Regional Pricing:**
   - Google will suggest local prices for all countries
   - Review and adjust as needed
   - You can exclude certain countries if desired

4. **Subscription Management:**
   - Users manage subscriptions through Google Play (you don't need to build cancellation UI)
   - Refunds are handled by Google Play policies

5. **Real-Time Developer Notifications:**
   - Set this up in **Monetization Setup** → **Real-time developer notifications**
   - Required for reliable subscription status updates
   - Use your backend URL to receive notifications

---

## 🧪 Testing Checklist

Before going live with subscriptions:

- [ ] Add test Gmail accounts to License Testing
- [ ] Test purchasing the subscription
- [ ] Verify premium features unlock in the app
- [ ] Test subscription expiration (use 5-minute test subscription)
- [ ] Test restoring purchases on a new device
- [ ] Test what happens when payment fails (grace period)
- [ ] Verify Supabase `user_premium_status` table updates correctly

---

## 🎮 Current Implementation

Your app is NOW fully set up with:
- ✅ `in_app_purchase` package installed
- ✅ `SubscriptionService` class with both subscription and consumable support
- ✅ Purchase flow in `PremiumSubscriptionScreen` (subscription)
- ✅ Purchase flow in `GameAchievementsScreen` (AI packs)
- ✅ Premium status check: `isPremiumActive()`
- ✅ Restore purchases functionality
- ✅ Supabase integration for premium tracking
- ✅ AI credit system fully integrated (`add_ai_pack_credits` RPC)
- ✅ Consumable purchase flow implemented

**All Product IDs are READY:**
- ✅ `statusxp_premium_monthly` - Subscription (fully implemented)
- ✅ `statusxp_ai_pack_small` - Consumable (fully implemented)
- ✅ `statusxp_ai_pack_medium` - Consumable (fully implemented)
- ✅ `statusxp_ai_pack_large` - Consumable (fully implemented)

**Create ALL 4 products in Google Play Console!**

---

## 📋 Quick Copy-Paste Values

For easy copy-pasting into Google Play Console:

### Premium Subscription

**Product ID:**
```
statusxp_premium_monthly
```

**Name:**
```
StatusXP Premium
```

**Description:**
```
Unlock unlimited AI achievement guides, faster sync cooldowns, premium badge, and priority support. Monthly subscription with 7-day free trial.
```

**Benefits List (for store display):**
```
• Unlimited AI Achievement Guides
• 12 PSN syncs per day (vs 3 free)
• 30-minute PSN sync cooldown (vs 2 hours free)
• 15-minute Xbox/Steam cooldown (vs 1 hour free)
• Premium Badge on your profile
• Priority Support
• Support ongoing development
```

---

### AI Credit Packs (Optional - For Future Implementation)

**Small Pack Product ID:**
```
statusxp_ai_pack_small
```

**Small Pack Name:**
```
AI Pack S
```

**Small Pack Description:**
```
20 AI Achievement Guides - Get personalized achievement strategies on demand!
```

---

**Medium Pack Product ID:**
```
statusxp_ai_pack_medium
```

**Medium Pack Name:**
```
AI Pack M - Best Value!
```

**Medium Pack Description:**
```
60 AI Achievement Guides - Best value at ~8¢ per guide!
```

---

**Large Pack Product ID:**
```
statusxp_ai_pack_large
```

**Large Pack Name:**
```
AI Pack L
```

**Large Pack Description:**
```
150 AI Achievement Guides - Maximum value for power users!
```

---

## ✅ You're Ready!

**Create ALL 4 products in Google Play Console:**

### Subscription Product:
- `statusxp_premium_monthly` - $4.99/month with 7-day trial

### Consumable Products (AI Packs):
- `statusxp_ai_pack_small` - $1.99 (20 credits)
- `statusxp_ai_pack_medium` - $4.99 (60 credits) 
- `statusxp_ai_pack_large` - $9.99 (150 credits)

Your app will automatically detect all products and enable purchases!

**Important:** AI packs are automatically hidden from premium users. Free users see both upgrade options:
1. Subscribe to Premium ($4.99/mo) = Unlimited AI forever
2. Buy AI Pack ($1.99-$9.99) = One-time credits, no subscription

**Next step:** Create all 4 products in Google Play Console using the info above.
