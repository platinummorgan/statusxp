# iOS App Store Submission Checklist

## Before Opening Xcode on Mac

1. **Pull Latest Changes**
   ```bash
   git pull origin main
   ```

2. **Open Xcode Project**
   ```bash
   open ios/Runner.xcworkspace
   ```

## Xcode Configuration

### 1. Code Signing & Capabilities
- Select **Runner** target
- Go to **Signing & Capabilities** tab
- Enable **Automatic Signing**
- Select your **Team** (Apple Developer account)
- Verify **Bundle Identifier**: `com.statusxp.statusxp`

### 2. Add In-App Purchase Capability
- Click **+ Capability**
- Search and add **In-App Purchase**
- The `Runner.entitlements` file is already configured

### 3. Verify Info.plist
- Already configured with proper display name
- Privacy descriptions should be added if not present

### 4. Build Settings
- Set **iOS Deployment Target**: 13.0 or higher
- Verify **Swift Language Version**: 5.0

## App Store Connect Configuration

### 1. Create App Listing
- Login to [App Store Connect](https://appstoreconnect.apple.com)
- Create new app with Bundle ID: `com.statusxp.statusxp`
- Set app name: **StatusXP**
- Select primary category: **Utilities** or **Entertainment**

### 2. Configure In-App Purchase (CRITICAL)
- Go to **Features** → **In-App Purchases**
- Click **+** to create new subscription
- **Product ID**: `statusxp_premium_monthly`
- **Reference Name**: StatusXP Premium Monthly
- **Subscription Group**: Create "Premium Subscription"
- **Duration**: 1 Month
- **Price**: $4.99 USD

#### Subscription Localization
- **Display Name**: Premium Subscription
- **Description**: Unlock unlimited AI guides and faster platform syncs

### 3. App Information
- **Privacy Policy URL**: Add your privacy policy URL
- **Support URL**: Add support website or email
- **Age Rating**: Complete questionnaire (likely 4+)

### 4. Screenshots Required
- **iPhone 6.7"** (Pro Max): 1290 x 2796 pixels
- **iPhone 6.5"** (standard): 1242 x 2688 pixels
- **iPad Pro 12.9"**: 2048 x 2732 pixels (if supporting iPad)

Minimum: 3 screenshots per size

## Build & Upload

### 1. Archive the App
```bash
# From project root
flutter build ios --release
```

Or in Xcode:
- Select **Any iOS Device (arm64)** as destination
- Product → Archive
- Wait for build to complete

### 2. Distribute to App Store
- In Xcode Organizer (Window → Organizer)
- Select your archive
- Click **Distribute App**
- Select **App Store Connect**
- Upload

### 3. Submit for Review
- Return to App Store Connect
- Select your build under **App Store** → **iOS App**
- Fill in **What's New in This Version**
- Add required screenshots
- Complete all required fields
- Click **Submit for Review**

## Testing Before Submission

### TestFlight Beta Testing (Recommended)
1. Upload build to App Store Connect
2. Wait for processing (usually 15-30 minutes)
3. Add yourself as internal tester
4. Install TestFlight app on iPhone
5. Test premium subscription with **Sandbox Tester Account**

### Create Sandbox Tester
- App Store Connect → Users and Access → Sandbox Testers
- Create test account with different email
- Use this account in TestFlight to test purchases

## Review Timeline
- Initial review: 24-48 hours typically
- Subscription apps may take longer (up to 5 days)
- Be ready to respond to any App Review questions

## Common Rejection Reasons (Avoid These)
- Missing privacy policy
- Incomplete subscription description
- Missing restore purchases button (✓ Already implemented)
- App crashes on launch
- Login issues

## Post-Approval
1. Enable subscription in "Pricing and Availability"
2. Test real purchase flow with production app
3. Monitor subscription dashboard in App Store Connect

---

**Current Status:** 
- ✅ Code is iOS-ready
- ✅ Entitlements configured
- ✅ In-App Purchase integrated
- ✅ Restore purchases implemented
- ⏳ Needs: Xcode signing, App Store Connect setup, build upload

**Product ID to Configure:** `statusxp_premium_monthly`
**Price:** $4.99/month
