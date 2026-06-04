# Sana — App Store Metadata

## App name
Sana: AI Nutrition Coach

## Subtitle (30 chars max)
AI meal tracker & macro coach

---

## Promotional text (170 chars max — shown at top, changeable without resubmission)
Snap a photo of any meal and get instant nutrition facts, macro breakdowns, and personalised coaching — powered by Claude AI.

---

## Description (4000 chars max)

Meet Sana, your personal AI nutrition coach. Whether you're tracking calories, managing macros, or building healthier habits, Sana makes it effortless — just snap a photo and let AI do the work.

**INSTANT PHOTO ANALYSIS**
Point your camera at any meal and Sana estimates calories, protein, carbs, fat, and fibre in seconds. Our Claude AI also gives you a health score and practical suggestions for every meal.

**MULTIPLE WAYS TO LOG**
• 📷 Camera AI — photograph your food for instant nutrition breakdown
• 🔤 Manual entry — type a meal with natural language ("2 eggs, toast")
• 🗣 Voice log — just say what you ate
• 📊 Barcode scanner — scan any packaged food
• 📋 Nutrition label scanner — photograph the label directly
• 🔁 Quick re-log — one tap to re-log any saved favourite

**YOUR PERSONAL AI COACH**
Chat with Sana's built-in AI coach for evidence-based nutrition advice, meal ideas, recipe suggestions, and strategies tailored to your goals, dietary style, and health conditions.

**SMART DASHBOARD**
• Calorie ring with real-time deficit/surplus tracking
• Macro bars (protein, carbs, fat, fibre)
• Daily score (0–100) across calories, protein, hydration, meal quality, and activity
• Weight goal progress with estimated weeks-to-goal
• Apple Health sync (steps, active calories, sleep, heart rate)
• 7-day calorie forecast based on your eating patterns

**MEAL PLANNING**
Generate a personalised weekly meal plan in one tap — Sana builds it around your calorie target, dietary style, allergies, and food preferences. Swap any meal you don't like, and generate a grocery list automatically.

**INSIGHTS & TRENDS**
• 17-week meal contribution heatmap
• Week-on-week nutrition comparison
• 7-day hydration trend chart
• Sleep vs nutrition correlation (via Apple Health)
• Weight history chart (kg or lbs)
• Nutrient deficiency detection

**HEALTH-AWARE**
Tell Sana about diabetes, anemia, PCOS, celiac, and 11 other conditions. Every suggestion and meal plan accounts for your specific needs.

**SUPPLEMENTS & FASTING**
Log your daily vitamins with streak tracking, and run a fasting timer that lives in the Dynamic Island with a live countdown.

**IMPERIAL & METRIC**
Full support for US, UK, and metric units — lbs, oz, ft/in, fl oz, or kg, ml, cm throughout the entire app.

**APPLE HEALTH**
Read steps, active calories, sleep, and resting heart rate. Sana uses this data to refine your coaching and daily score.

**ACHIEVEMENT BADGES**
Unlock 15 badges for streaks, hydration goals, photo analyses, protein targets, and more.

**PRIVACY-FIRST**
All your data stays on your device. Meal photos are sent to Claude AI for analysis only — never stored on our servers.

---

## Keywords (100 chars max — comma-separated, no spaces after commas)
nutrition,calorie,macro,meal,AI,diet,health,weight,food,tracker,coach,protein,carb,fitness,log

---

## Category
Primary: Health & Fitness
Secondary: Food & Drink

---

## Age Rating
4+ (no objectionable content)

---

## Support URL
https://github.com/mcagridemir/sana-support  (create a GitHub repo with a README as the support page)
— OR —
https://sana-ai-proxy.cagriidemirr.workers.dev/support  (add a /support route to your Worker)

## Privacy Policy URL
https://mcagridemir.github.io/sana-privacy  (see privacy_policy.md for the content to host)
— OR —
Add a /privacy route to your Cloudflare Worker (see worker_privacy_route.js)

## Marketing URL (optional)
Leave blank for now

---

## App Review Notes (for Apple reviewer)
Sana uses the camera to photograph food for AI nutrition analysis. The AI coach feature uses the Anthropic Claude API via a Cloudflare Worker proxy — the API key is never stored in the app binary. Apple Health access is optional and used only to display step count, active calories, and sleep data within the app. All user data is stored locally on device via SwiftData. No account is required — Sign in with Apple is the only authentication method offered.

---

## What to Prepare for Screenshots
Required sizes:
- iPhone 6.9" (iPhone 16 Pro Max) — 1320 × 2868 px
- iPhone 6.7" (iPhone 15 Plus) — 1290 × 2796 px  
- iPad 13" (M4 iPad Pro) — 2064 × 2752 px (if submitting iPad)

Recommended screenshot order (5–6 screenshots):
1. Dashboard with calorie ring + hero card (dark hero + green ring)
2. Camera AI analysis — show meal photo + result card
3. AI Coach conversation
4. Insights screen — heatmap + week comparison
5. Meal plan with grocery list
6. Daily score + achievements

Use Xcode Simulator to capture:
  Device → Window → Screenshot  (Cmd+S)
Then open in Simulator → File → Save Screenshot

Or use a tool like Rottenwood / ScreenshotKit / Fastlane Snapshot for automation.
