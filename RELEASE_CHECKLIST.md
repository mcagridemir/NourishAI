# Sana — App Store Release Checklist

Status legend: ✅ done · ⛔ blocker (must do before submit) · 🔁 recurring/verify

Last updated: 2026-06-15

---

## 1. Code & build health — ✅ done
- ✅ Clean build with **zero warnings** (code + assets) — Sana scheme, iOS Simulator.
- ✅ 103 unit + UI tests pass (`SanaTests` + `SanaUITests`).
- ✅ Localization parity across all 6 languages (de, en, es, fr, pt-BR, tr) — 662 keys each, `plutil`-clean, format specifiers verified.
- ✅ Accessibility: VoiceOver labels on icon-only buttons, Dynamic Type scales, shrink-to-fit on name labels.
- ✅ Light/dark adaptive colors; AppIcon ships Any/Dark/Tinted (iOS 18) variants.
- ✅ Swift 6 main-actor isolation warnings resolved.
- ✅ `main` pushed and in sync with origin.

## 2. Secrets / config for a real build — ⛔ verify before archiving
The committed sources hold **empty placeholders** by design — a clean checkout will NOT reach the backend. Before archiving a Release build, confirm your **local** working copy has the real values (and never commit them):
- ⛔ `Sana/Core/Config/BackendConfig.swift` — real `appSecret` (matches the Worker's `APP_SECRET`). Committed value must stay `""`.
- ⛔ `Sana/Core/Config/APIKeyStore.swift` — populated obfuscated byte arrays (or rely on the proxy). Committed values must stay `[]`.
- ⛔ `GoogleService-Info.plist` present locally (gitignored — never commit).
- 🔁 Confirm `BackendConfig.proxyURL` points at the production Worker: `https://sana-ai-proxy.cagriidemirr.workers.dev`.

## 3. App Store Connect — ⛔ blockers (portal work)
- ⛔ Create the app record at appstoreconnect.apple.com (bundle id `com.cagri.Sana`).
- ⛔ Create auto-renewable subscription products: `com.sana.premium.monthly` ($4.99/mo) and `com.sana.premium.yearly` ($39.99/yr, ~33% off) (+ a subscription group, localized display names, prices, and a 7-day free-trial intro offer). Until these exist the paywall shows no prices. The local `Sana.storekit` file mirrors this exact setup — match it in App Store Connect.
- ⛔ Fill App Privacy ("Nutrition Disclosure" / data types: Health, Identifiers, etc.).
- ⛔ Age rating, category (Health & Fitness), pricing/availability.

## 4. Provisioning & capabilities — ⛔ blockers (developer portal)
- ⛔ Widget App ID provisioning for `com.cagri.Sana.SanaWidget` (was rate-limited earlier at developer.apple.com).
- 🔁 App Group `group.com.cagri.Sana` enabled on app + widget + watch.
- 🔁 Capabilities: HealthKit, Push/Notifications, App Groups, (CloudKit is currently OFF — `BackendConfig.cloudKitEnabled = false`; can stay off for v1).

## 5. Firebase — ⛔ blocker
- ⛔ Enable **Google** sign-in provider in Firebase Console → Authentication (client ID is in the plist but the provider isn't enabled).
- 🔁 Crashlytics: confirm dSYM upload works on a Release/device build.

## 6. Store listing assets — ⛔ blockers
- ⛔ **Screenshots** — automated: see `SanaUITests/ScreenshotTests.swift` and the "Generating screenshots" section below. Required sizes: 6.9" (iPhone 16 Pro Max) and 13" (iPad Pro) at minimum; capture per locale.
- ⛔ App description, keywords, promo text, "What's New" — per locale (6 languages). **Drafted and length-checked in `AppStore/store-listing.md`** — paste into App Store Connect.
- ⛔ Privacy policy URL + Support URL — hosted and reachable (privacy HTML is in `AppStore/privacy.html`).

## 7. Real-device pass — ⛔ before submit (can't be done in CI/sim)
- ⛔ Sandbox StoreKit purchase of monthly + yearly; restore purchases.
- ⛔ HealthKit read/write authorization + data sync.
- ⛔ Trigger a test crash → relaunch → confirm it appears in Crashlytics.
- ⛔ Home-screen widget renders; Live Activity (fasting) starts/updates/ends.
- ⛔ App icon (incl. Dark / Tinted) looks correct on the home screen.
- ⛔ Push/local notifications fire and deep-link correctly.

---

## Generating screenshots (automated)

`SanaUITests/ScreenshotTests.swift` launches the app with `-uitest-demo` (a DEBUG-only
hook that bypasses auth/onboarding and seeds a populated user), then captures the
Dashboard, Insights, Meal Plan, Coach, and Paywall.

Run one locale + device:

```sh
xcodebuild test -scheme Sana \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' \
  -only-testing:SanaUITests/ScreenshotTests \
  -testLanguage de -testRegion DE
```

Export the captured PNGs from the result bundle:

```sh
RESULT=$(ls -dt ~/Library/Developer/Xcode/DerivedData/Sana-*/Logs/Test/*.xcresult | head -1)
xcrun xcresulttool export attachments --path "$RESULT" --output-path ./shots
# names map via shots/manifest.json (01-Dashboard … 05-Paywall)
```

Repeat per language (`en`/`de`/`es`/`fr`/`pt-BR`/`tr`) and per device size.

**Caveat:** the Paywall's price cards are blank in the simulator because StoreKit
has no products by default. A ready-made config exists at `Sana.storekit` (the two
product IDs, $4.99/mo + $39.99/yr, 7-day free trial). To use it: add `Sana.storekit`
to the project once (drag into the navigator, no target membership needed), then
Edit Scheme → Run **and** Test → Options → StoreKit Configuration → select it.
The paywall will then show real prices in the simulator and in screenshots.
