# Privacy Policy — Sana

_Last updated: May 2026_

## Overview

Sana ("the app") is a personal nutrition tracking application. We are committed to protecting your privacy. This policy explains what data Sana collects, how it is used, and your rights.

---

## Data We Collect

### Data stored on your device (never sent to us)
Sana stores all personal data locally on your device using Apple's SwiftData framework:

- **Meal entries** — name, calories, macros, health score, photos, timestamps
- **Weight entries** — dates and weights
- **Water intake entries** — amounts and timestamps
- **Supplement logs** — supplement names, dosages, check-in history
- **User profile** — name, age, height, weight, goals, dietary preferences, health conditions
- **Meal plans** — AI-generated weekly plans and grocery lists
- **Coach conversations** — chat history with the AI coach

This data is stored in your device's private container and, if you enable CloudKit sync, in your personal iCloud account.

### Data sent off-device

Sana sends certain data to third-party services **only to provide app functionality**:

| Data | Sent to | Purpose |
|------|---------|---------|
| Meal photos | Anthropic (Claude API) via our Cloudflare proxy | AI food recognition and nutrition analysis |
| Meal descriptions / coach messages | Anthropic (Claude API) via our Cloudflare proxy | AI nutrition coaching responses |
| Nutrition context (calories, macros, goals) | Anthropic (Claude API) via our Cloudflare proxy | Personalised AI advice |
| Anonymous crash logs | Google Firebase Crashlytics | App stability improvements |
| Anonymous usage events | Google Firebase Analytics | Understanding feature usage |

**Anthropic Claude API:** Meal images and text are sent to Anthropic's Claude API to provide real-time nutrition analysis and coaching. Anthropic's data processing is governed by [Anthropic's Privacy Policy](https://www.anthropic.com/privacy). We do not use the "training on user content" option; data sent to the API is not used to train Anthropic's models.

**Firebase:** Crash reports contain no personally identifiable information. Analytics events are anonymised and aggregated.

---

## Apple Health

Sana may request access to Apple HealthKit to read:
- Step count
- Active energy burned
- Sleep analysis
- Resting heart rate

This data is read from your Health app and displayed within Sana. It is **never** sent to any external server. Access is optional and can be revoked at any time in iOS Settings → Privacy → Health → Sana.

---

## Authentication

Sana uses **Sign in with Apple** for account creation. We receive only:
- A unique, anonymised Apple user identifier
- Your name and email address (only if you choose to share them)

We do not store your Apple credentials. Sign-in state is stored in the iOS Keychain on your device.

---

## Data Sharing

We do **not** sell, rent, or share your personal data with third parties for advertising or marketing purposes.

Data is shared only as described above (Anthropic for AI features, Firebase for crash/analytics), solely to provide and improve app functionality.

---

## Data Retention

- **Device data:** Stored until you delete the app or clear app data.
- **iCloud data (if CloudKit sync is enabled):** Stored in your personal iCloud account under your control.
- **API data:** Meal images and messages sent to Anthropic's API are processed in real time. Anthropic may retain them per their own data retention policy.
- **Firebase data:** Crash reports are retained for 90 days. Analytics data is aggregated and anonymised.

---

## Your Rights

You can:
- **Access and export** your meal data via Profile → Export meal data (CSV)
- **Delete** your data by deleting the app (removes all local data)
- **Revoke** HealthKit access in iOS Settings at any time
- **Opt out** of Firebase Analytics: we do not currently offer an in-app toggle, but you can contact us to request exclusion

---

## Children

Sana is rated 4+ and does not knowingly collect personal information from children under 13. If you believe a child has provided personal information, please contact us for removal.

---

## Changes to This Policy

We may update this policy as the app evolves. Material changes will be noted in the app's release notes. Continued use of the app after changes constitutes acceptance.

---

## Contact

For privacy questions or data deletion requests:

**Developer:** Çağrı Demir  
**Email:** [your support email here]  
**GitHub:** https://github.com/mcagridemir

---

## Hosting Instructions

To make this policy available at a URL for App Store Connect:

### Option A — GitHub Pages (free, 5 minutes)
1. Create a public repo named `sana-privacy` at github.com/mcagridemir
2. Add this file as `index.md` (GitHub Pages renders Markdown automatically with a theme)
3. Go to repo Settings → Pages → Source: main branch → Save
4. Your URL: `https://mcagridemir.github.io/sana-privacy`

### Option B — Cloudflare Worker route (already have Worker deployed)
Add to `worker.js`:
```js
if (request.method === 'GET' && new URL(request.url).pathname === '/privacy') {
  return new Response(PRIVACY_HTML, { headers: { 'Content-Type': 'text/html' } });
}
```
Then define `PRIVACY_HTML` as the HTML version of this policy.

### Option C — Cloudflare Pages (free)
1. `npx wrangler pages deploy AppStore/ --project-name sana-pages`
2. Add a `index.html` to the AppStore folder with this policy in HTML
