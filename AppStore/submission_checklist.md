# Sana — App Store Submission Checklist

## 1 · Code / Xcode (done in Claude Code)
- [x] BUILD SUCCEEDED for Sana scheme
- [x] Privacy manifest (PrivacyInfo.xcprivacy) — covers UserDefaults, FileTimestamp, DiskSpace, SystemBootTime
- [x] App icons present (light, dark, tinted)  ← **3 1024×1024 PNGs are missing** (see Asset Catalog warnings)
- [x] Bundle ID: com.cagri.Sana
- [x] Version 1.0, Build 1
- [x] Entitlements: Sign in with Apple, HealthKit, Push Notifications, App Groups

## 2 · Xcode — Before Archiving

### Fix the 3 missing App Icon PNGs (blocking)
The build warns about missing 1024×1024 icons:
- `light/ios-marketing.png`
- `dark/ios-marketing.png`
- `tinted/ios-marketing.png`

**Steps:**
1. Open Xcode → `Sana/Assets.xcassets` → `AppIcon`
2. In the AppIcon set, drag a 1024×1024 PNG into each of the Light, Dark, and Tinted slots
3. Alternatively, set the `AppIcon` set back to "Single" mode if you only have one icon

### Set correct signing for widget
- Widget target (`SanaWidgetExtension`) may need manual provisioning
- If `com.cagri.Sana.SanaWidget` App ID was blocked by Apple's rate limit earlier, check developer.apple.com → Identifiers now

### Archive
```
Product → Archive → Distribute App → App Store Connect → Upload
```

## 3 · App Store Connect Setup

### Create the app
1. Go to appstoreconnect.apple.com
2. My Apps → + → New App
3. Platform: iOS
4. Name: **Sana: AI Nutrition Coach**
5. Primary Language: English
6. Bundle ID: `com.cagri.Sana` (must match Xcode)
7. SKU: `sana-nutrition-001`
8. User Access: Full Access

### App Information
- Category: Health & Fitness (Primary), Food & Drink (Secondary)
- Content Rights: Does not contain, display, or access third-party content ✓
- Age Rating: 4+
  - Unrestricted Web Access: No
  - Gambling: No
  - All other categories: None

### Pricing
- Free (with In-App Purchase for premium)

### In-App Purchases (if using RevenueCat)
- Product ID: `sana.premium.monthly`
- Reference Name: Sana Premium Monthly
- Price: $4.99/month (or your chosen price)
- Type: Auto-Renewable Subscription
- Subscription Group: Sana Premium

## 4 · App Store Listing

Paste content from `app_store_metadata.md`:
- [ ] Promotional text (170 chars)
- [ ] Description (full 4000-char copy)
- [ ] Keywords: `nutrition,calorie,macro,meal,AI,diet,health,weight,food,tracker,coach,protein,carb,fitness,log`
- [ ] Support URL (GitHub or Cloudflare — create first)
- [ ] Privacy Policy URL (host first — see `privacy_policy.md`)
- [ ] Marketing URL (optional, leave blank)

## 5 · Screenshots

**Required (blocking — can't submit without these):**
- iPhone 6.9" — at least 3 screenshots, up to 10
- iPhone 6.7" — OR check "Use iPhone 6.9" screenshots" in App Store Connect

**Capture steps:**
1. Run app in Simulator → iPhone 16 Pro Max
2. Navigate to the screen you want
3. In Simulator menu: File → Save Screenshot (Cmd+S) — saves to Desktop
4. Edit in Preview/Figma to add device frames if desired

**Recommended 6 screenshots:**
1. Dashboard — calorie ring, hero card, streak
2. Meal analysis — camera result with health score
3. AI Coach conversation
4. Insights — heatmap + week comparison chart
5. Meal plan — weekly view with day tabs
6. Achievements + daily score

## 6 · Before Submitting for Review

- [ ] Privacy policy URL is live and accessible
- [ ] Support URL is live and accessible
- [ ] App Review Notes filled in (see `app_store_metadata.md`)
- [ ] App previews / screenshots uploaded
- [ ] In-App Purchase configured (if applicable)
- [ ] "Sign in with Apple" tested on real device
- [ ] HealthKit tested on real device
- [ ] Camera/barcode tested on real device (Simulator has no camera)
- [ ] Crashlytics test crash confirmed in Firebase dashboard
- [ ] Widget tested on real device (if provisioning is resolved)

## 7 · Post-Submission

- Apple review typically takes **1–3 business days**
- You'll receive email on approval or rejection
- If rejected, read the rejection reason carefully — common causes:
  - Missing privacy policy URL
  - App crashes during review
  - Missing demo account (not needed here since Sign in with Apple is self-contained)
  - Incomplete features referenced in screenshots

## 8 · Pending User-Action Items (needed before or after launch)

| Item | What's needed |
|------|--------------|
| App icons | 3 × 1024×1024 PNG (light, dark, tinted) added to asset catalog |
| Privacy policy URL | Host `privacy_policy.md` at a public URL |
| Support URL | Create GitHub repo or Cloudflare Page |
| RevenueCat | Add API key to `BackendConfig` → wire into `SubscriptionService` |
| Google Sign-In | Firebase Console → Authentication → enable Google → download new `GoogleService-Info.plist` |
| Widget provisioning | `com.cagri.Sana.SanaWidget` App ID + profile |
| CloudKit | Enable in Developer Portal (can wait until v1.1) |
| Crashlytics test | Run on real device, force a crash, verify Firebase dashboard |
