---
name: nourishai-swiftui-architect
description: >
  Scaffolds, reviews, and refactors SwiftUI code for the NourishAI project.
  Use this skill when asked to create or update views, viewmodels, services,
  or data models. Enforces the exact architecture patterns already established
  in the codebase to prevent conflicts.
dependencies: swift>=5.9, ios>=17
---

# NourishAI SwiftUI Architect

## 1. Project Context
NourishAI is a production iOS nutrition coaching app using:
- SwiftUI + SwiftData for UI and persistence
- Claude (Anthropic) API for AI features (meal analysis, chat, meal plans)
- HealthKit for activity/sleep data
- StoreKit 2 for subscriptions
- The codebase is live and building — never introduce patterns that break existing files

## 2. Architecture: MVVM with ObservableObject

### ViewModels — always use this pattern:
```swift
import Foundation
import SwiftUI
import Combine

@MainActor
final class FeatureViewModel: ObservableObject {

    @Published var state: ViewState = .idle
    @Published var error: String?

    private let user: User

    init(user: User) {
        self.user = user
    }

    enum ViewState {
        case idle
        case loading
        case result(SomeType)
        case error(String)
    }

    func performAction() async {
        state = .loading
        do {
            // call ClaudeService, HealthKitService, etc.
            let result = try await ClaudeService.shared.someMethod()
            state = .result(result)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
```

### Views — always use this pattern:
```swift
import SwiftUI

struct FeatureView: View {

    @Bindable var user: User
    @StateObject private var vm: FeatureViewModel
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    init(user: User) {
        self.user = user
        _vm = StateObject(wrappedValue: FeatureViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Feature")
                .navigationBarTitleDisplayMode(.inline)
        }
        .task { await vm.performAction() }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.state {
        case .idle, .loading:
            LoadingCard(message: "Loading...")
        case .result(let data):
            resultView(data)
        case .error(let msg):
            ErrorBanner(message: msg, retry: { Task { await vm.performAction() } })
        }
    }
}
```

## 3. Critical Rules — Never Violate These

### ❌ NEVER do this:
```swift
// WRONG — causes "does not conform to ObservableObject" errors
@Observable
final class SomeViewModel: ObservableObject { ... }

// WRONG — causes missing Combine import errors
internal import Combine

// WRONG — causes init errors
var objectWillChange: ObservableObjectPublisher
```

### ✅ ALWAYS do this:
```swift
// CORRECT
import Combine

@MainActor
final class SomeViewModel: ObservableObject {
    @Published var someProperty = ""
}
```

### Never mix @Observable with ObservableObject
- Use `ObservableObject` + `@Published` + `@StateObject` — this is what the whole codebase uses
- Do NOT use `@Observable` macro — it conflicts with `@StateObject` in our Views
- Do NOT use `internal import` — always use regular `import`

## 4. Theming — Always Use NourishTheme

```swift
// Colors
NourishTheme.Color.primary        // #2D9E75 green
NourishTheme.Color.primaryLight   // #E1F5EE light green
NourishTheme.Color.accent         // #F0853A orange
NourishTheme.Color.surface        // white cards
NourishTheme.Color.background     // #F5F5F5 page background
NourishTheme.Color.macro(.protein) // blue
NourishTheme.Color.macro(.carbs)   // amber
NourishTheme.Color.macro(.fat)     // coral
NourishTheme.Color.macro(.fiber)   // green
NourishTheme.Color.healthScore(score) // green/orange/red by value

// Typography
NourishTheme.Font.title(28)       // rounded bold
NourishTheme.Font.headline(17)    // semibold
NourishTheme.Font.body(15)        // regular
NourishTheme.Font.caption(12)     // medium small

// Spacing
NourishTheme.Spacing.xs  // 4
NourishTheme.Spacing.sm  // 8
NourishTheme.Spacing.md  // 16
NourishTheme.Spacing.lg  // 24
NourishTheme.Spacing.xl  // 32

// Corner radius
NourishTheme.Radius.sm   // 8
NourishTheme.Radius.md   // 12
NourishTheme.Radius.lg   // 20
NourishTheme.Radius.xl   // 28

// Animations
NourishTheme.Animation.snappy  // spring
NourishTheme.Animation.smooth  // easeInOut 0.3s

// Card modifier
.nourishCard()  // adds padding + white background + rounded corners

// Button style
.buttonStyle(NourishButtonStyle())         // primary green
.buttonStyle(NourishButtonStyle(isPrimary: false)) // secondary
```

## 5. SwiftData Models — Key Relationships

```swift
// User is the root model — everything hangs off it
user.mealEntries     // [MealEntry]
user.mealPlans       // [MealPlan]
user.chatMessages    // [ChatMessage]
user.nutritionContext // UserNutritionContext (for Claude API calls)
user.canAnalyzeMeal  // Bool (free tier check)
user.subscriptionTier // .free or .premium

// MealEntry
entry.calories, .protein, .carbohydrates, .fat, .fiber
entry.healthScore    // 0-100
entry.aiInsights     // [String]
entry.mealType       // MealType enum

// MealPlan → MealPlanDay → PlannedMeal
plan.days            // [MealPlanDay]
day.breakfastMeal, .lunchMeal, .dinnerMeal, .snackMeals
meal.isCompleted     // user ticks off
```

## 6. Services — How to Call Them

```swift
// Claude API — meal photo analysis
let analysis = try await ClaudeService.shared.analyzeMeal(
    image: uiImage,
    mealType: .lunch,
    context: user.nutritionContext
)

// Claude API — streaming chat
let stream = await ClaudeService.shared.streamChat(
    messages: chatMessages,
    context: user.nutritionContext
)
for try await chunk in stream {
    self.streamingText += chunk
}

// Claude API — meal plan
let plan = try await ClaudeService.shared.generateMealPlan(
    days: 3,
    context: user.nutritionContext
)

// Claude API — grocery list
let sections = try await ClaudeService.shared.generateGroceryList(from: planResponse)

// Claude API — weekly insights
let insight = try await ClaudeService.shared.generateWeeklyInsights(context: user.nutritionContext)

// HealthKit
try await HealthKitService.shared.requestAuthorization()
await HealthKitService.shared.refreshAll()
healthKit.todaySteps, .todayActiveCalories, .lastNightSleep

// Subscriptions
subscription.isPremium
try await subscription.purchase(product)
```

## 7. Reusable Components — Use These, Don't Reinvent

```swift
MacroRingView(calories:target:protein:carbs:fat:)
MacroPillsView(protein:carbs:fat:fiber:)
HealthScoreBadge(score:size:)
StreamingTextView(text:isStreaming:)
TypingIndicator()
LoadingCard(message:)
ErrorBanner(message:retry:)
NourishTextField(placeholder:text:)
SelectionRow(label:isSelected:action:)
SelectionTile(label:isSelected:action:)
FlowLayout(items:content:)
```

## 8. File Naming & Folder Structure

```
Features/
  FeatureName/
    FeatureNameView.swift       // SwiftUI View
    FeatureNameViewModel.swift  // ObservableObject ViewModel
Models/
  ModelName.swift               // @Model SwiftData class
Services/
  ServiceName.swift             // actor or final class
Core/
  Components/                   // reusable views
  Theme/NourishTheme.swift      // design system
  Extensions/Extensions.swift   // Swift extensions
```

## 9. SwiftUI Previews — Always Add These

```swift
#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: User.self, configurations: [config])
    let user = User(name: "Preview User", email: "preview@test.com")
    container.mainContext.insert(user)
    return FeatureView(user: user)
        .modelContainer(container)
}
```

## 10. Code Quality Checklist

Before finishing any file:
- [ ] All ViewModels use `ObservableObject` + `@Published` (not `@Observable`)
- [ ] All Views use `@StateObject` for ViewModels
- [ ] `import Combine` not `internal import Combine`
- [ ] No `var objectWillChange: ObservableObjectPublisher`
- [ ] All colors from `NourishTheme.Color`
- [ ] All fonts from `NourishTheme.Font`
- [ ] Error states handled with `ErrorBanner`
- [ ] Loading states handled with `LoadingCard`
- [ ] SwiftData changes go through `user` relationships (not direct context inserts where possible)
- [ ] Claude API calls use `user.nutritionContext` for personalisation
