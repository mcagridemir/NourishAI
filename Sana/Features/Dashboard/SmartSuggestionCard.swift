// Sana — SmartSuggestionCard.swift
// Heuristic next-meal suggestion based on remaining macros and time of day.
import SwiftUI
internal import Combine

// MARK: - View

struct SmartSuggestionCard: View {

    let user: User
    @State private var expanded = false

    private var remainingCalories: Int { max(0, user.dailyCalorieTarget - user.todayCalories) }
    private var remainingProtein: Double {
        let eaten = (user.mealEntries ?? []).filter { Calendar.current.isDateInToday($0.loggedAt) }.map { $0.protein }.reduce(0, +)
        return max(0, user.dailyProteinTarget - eaten)
    }

    private var mealTimeSuggestion: LocalSuggestion { LocalSuggestion.make(remaining: remainingCalories, protein: remainingProtein, hour: Calendar.current.component(.hour, from: .now), user: user) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Next Meal Idea", systemImage: "lightbulb.fill")
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(.yellow)
                Spacer()
                Text(mealTimeSuggestion.mealType)
                    .font(SanaTheme.Font.caption(11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(mealTimeSuggestion.color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: mealTimeSuggestion.icon)
                        .font(.system(size: 22))
                        .foregroundStyle(mealTimeSuggestion.color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(mealTimeSuggestion.name)
                        .font(SanaTheme.Font.headline(15))
                    Text(mealTimeSuggestion.description)
                        .font(SanaTheme.Font.body(13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Macro fit indicators
            HStack(spacing: 8) {
                macroFitChip(label: "~\(mealTimeSuggestion.calories) kcal", color: .orange)
                macroFitChip(label: "~\(mealTimeSuggestion.protein)g protein", color: .blue)
                macroFitChip(label: "\(mealTimeSuggestion.prepTime) min prep", color: .teal)
            }

            // Expandable ingredients
            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick recipe")
                        .font(SanaTheme.Font.caption(11))
                        .foregroundStyle(.secondary)
                    ForEach(mealTimeSuggestion.ingredients, id: \.self) { ing in
                        HStack(spacing: 6) {
                            Circle().fill(mealTimeSuggestion.color).frame(width: 5, height: 5)
                                .accessibilityHidden(true)
                            Text(ing).font(SanaTheme.Font.body(13))
                        }
                    }
                }
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                withAnimation(SanaTheme.Animation.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(expanded ? "Show less" : "See ingredients")
                        .font(SanaTheme.Font.caption(12))
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10))
                }
                .foregroundStyle(SanaTheme.Color.primary)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .nourishCard()
    }

    private func macroFitChip(label: String, color: Color) -> some View {
        Text(label)
            .font(SanaTheme.Font.caption(11))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }
}

// MARK: - Local heuristic suggestion (no API call needed)

struct LocalSuggestion {
    let name: String
    let description: String
    let mealType: String
    let calories: Int
    let protein: Int
    let prepTime: Int
    let ingredients: [String]
    let icon: String
    let color: Color

    static func make(remaining: Int, protein: Double, hour: Int, user: User) -> LocalSuggestion {
        let isVegan        = user.dietaryStyle == .vegan
        let isVegetarian   = user.dietaryStyle == .vegetarian || isVegan
        let isKeto         = user.dietaryStyle == .keto
        let isTurkish      = user.country.localizedCaseInsensitiveContains("turkey")
                          || user.country.localizedCaseInsensitiveContains("türkiye")
        let hasDiabetes    = user.healthConditions.contains { $0.localizedCaseInsensitiveContains("diabetes") }
        let hasCeliac      = user.healthConditions.contains { $0.localizedCaseInsensitiveContains("celiac") }
        let avoidRedMeat   = isVegetarian || user.healthConditions.contains { $0.localizedCaseInsensitiveContains("gout") }

        // MARK: Breakfast
        if hour < 11 {
            if isTurkish {
                if hasCeliac {
                    return LocalSuggestion(
                        name: "Menemen", description: "Gluten-free scrambled eggs with tomatoes, green peppers, and olive oil.",
                        mealType: MealType.breakfast.localizedName, calories: min(remaining, 310), protein: 18, prepTime: 10,
                        ingredients: ["3 eggs", "2 tomatoes", "1 green pepper", "2 tbsp olive oil", "Salt & spices"],
                        icon: "sunrise.fill", color: .orange)
                }
                if hasDiabetes {
                    return LocalSuggestion(
                        name: "Turkish egg & cheese plate", description: "Low-GI breakfast with boiled eggs, white cheese, tomatoes, and cucumber — no bread.",
                        mealType: MealType.breakfast.localizedName, calories: min(remaining, 280), protein: 22, prepTime: 5,
                        ingredients: ["2 boiled eggs", "50g white cheese (beyaz peynir)", "2 tomatoes", "1 cucumber", "A few olives"],
                        icon: "sunrise.fill", color: .yellow)
                }
                return LocalSuggestion(
                    name: "Turkish breakfast (kahvaltı)", description: "Classic spread of white cheese, olives, tomatoes, cucumber, and an egg — with simit.",
                    mealType: MealType.breakfast.localizedName, calories: min(remaining, 420), protein: 20, prepTime: 5,
                    ingredients: ["1 simit", "50g beyaz peynir", "2 tomatoes", "1 cucumber", "A few black olives", "1 boiled egg"],
                    icon: "sunrise.fill", color: .orange)
            }
            if isVegan {
                return LocalSuggestion(
                    name: "Overnight oats with berries", description: "High-fibre oats with almond milk, chia seeds, and mixed berries.",
                    mealType: MealType.breakfast.localizedName, calories: min(remaining, 380), protein: 12, prepTime: 5,
                    ingredients: ["½ cup rolled oats", "1 cup almond milk", "1 tbsp chia seeds", "½ cup berries"],
                    icon: "leaf.fill", color: .green)
            }
            if isKeto {
                return LocalSuggestion(
                    name: "Scrambled eggs with avocado", description: "Three eggs scrambled with butter, topped with half an avocado.",
                    mealType: MealType.breakfast.localizedName, calories: min(remaining, 420), protein: 22, prepTime: 8,
                    ingredients: ["3 large eggs", "1 tbsp butter", "½ avocado", "Salt & pepper", "Fresh chives"],
                    icon: "sunrise.fill", color: .yellow)
            }
            if hasDiabetes {
                return LocalSuggestion(
                    name: "Egg & vegetable scramble", description: "Low-GI scrambled eggs with spinach and tomatoes — no toast.",
                    mealType: MealType.breakfast.localizedName, calories: min(remaining, 290), protein: 22, prepTime: 8,
                    ingredients: ["3 eggs", "1 cup spinach", "1 tomato, diced", "1 tsp olive oil", "Salt & pepper"],
                    icon: "sunrise.fill", color: .green)
            }
            return LocalSuggestion(
                name: "Greek yoghurt parfait", description: "High-protein Greek yoghurt layered with granola and fresh fruit.",
                mealType: MealType.breakfast.localizedName, calories: min(remaining, 340), protein: 20, prepTime: 3,
                ingredients: ["200g Greek yoghurt (0%)", "30g granola", "½ cup mixed fruit", "1 tsp honey"],
                icon: "sunrise.fill", color: .orange)
        }

        // MARK: Lunch
        if hour < 15 {
            if isTurkish {
                if isVegetarian || hasDiabetes {
                    return LocalSuggestion(
                        name: "Mercimek çorbası", description: "Traditional Turkish red lentil soup — high in protein and fibre, naturally low-GI.",
                        mealType: MealType.lunch.localizedName, calories: min(remaining, 320), protein: 18, prepTime: 20,
                        ingredients: ["1 cup red lentils", "1 onion", "2 tbsp olive oil", "Cumin & paprika", "Lemon to serve"],
                        icon: "flame.fill", color: .red)
                }
                if avoidRedMeat || isKeto {
                    return LocalSuggestion(
                        name: "Tavuk şiş with salad", description: "Grilled chicken skewers with tomato, onion, and a crisp side salad.",
                        mealType: MealType.lunch.localizedName, calories: min(remaining, 420), protein: 40, prepTime: 20,
                        ingredients: ["200g chicken breast", "1 tomato", "½ onion", "Lemon & oregano", "Mixed salad leaves"],
                        icon: "bolt.heart.fill", color: .blue)
                }
                return LocalSuggestion(
                    name: "Köfte with bulgur", description: "Homestyle meatballs with bulgur pilav and a tomato-cucumber salad.",
                    mealType: MealType.lunch.localizedName, calories: min(remaining, 480), protein: 34, prepTime: 25,
                    ingredients: ["150g ground beef (lean)", "½ cup bulgur", "1 tomato", "1 cucumber", "Fresh parsley"],
                    icon: "fork.knife", color: SanaTheme.Color.primary)
            }
            if isVegetarian {
                return LocalSuggestion(
                    name: "Lentil & vegetable soup", description: "Hearty red lentil soup with spinach, tomatoes, and warming spices.",
                    mealType: MealType.lunch.localizedName, calories: min(remaining, 350), protein: 18, prepTime: 20,
                    ingredients: ["1 cup red lentils", "1 can diced tomatoes", "1 cup spinach", "1 onion", "Cumin & turmeric"],
                    icon: "flame.fill", color: .red)
            }
            if hasCeliac {
                return LocalSuggestion(
                    name: "Grilled chicken rice bowl", description: "Gluten-free chicken thigh over jasmine rice with roasted vegetables.",
                    mealType: MealType.lunch.localizedName, calories: min(remaining, 460), protein: 38, prepTime: 20,
                    ingredients: ["150g chicken thigh", "½ cup jasmine rice", "1 cup roasted vegetables", "2 tbsp olive oil", "Herbs & lemon"],
                    icon: "bolt.heart.fill", color: .blue)
            }
            if protein > 25 {
                return LocalSuggestion(
                    name: "Grilled chicken & quinoa bowl", description: "Lean chicken breast over fluffy quinoa with roasted vegetables.",
                    mealType: MealType.lunch.localizedName, calories: min(remaining, 480), protein: 42, prepTime: 25,
                    ingredients: ["150g chicken breast", "½ cup quinoa", "1 cup roasted vegetables", "2 tbsp olive oil", "Lemon & herbs"],
                    icon: "bolt.heart.fill", color: .blue)
            }
            return LocalSuggestion(
                name: "Tuna & avocado wrap", description: "Protein-rich tuna mixed with creamy avocado in a wholegrain wrap.",
                mealType: MealType.lunch.localizedName, calories: min(remaining, 420), protein: 32, prepTime: 8,
                ingredients: ["1 wholegrain wrap", "1 can tuna in water", "½ avocado", "1 tbsp Greek yoghurt", "Spinach & tomato"],
                icon: "fork.knife", color: SanaTheme.Color.primary)
        }

        // MARK: Snack
        if hour < 18 {
            if isTurkish {
                if hasCeliac || hasDiabetes {
                    return LocalSuggestion(
                        name: "Ayran with mixed nuts", description: "Refreshing homemade ayran with a small handful of unsalted mixed nuts.",
                        mealType: MealType.snack.localizedName, calories: 200, protein: 8, prepTime: 2,
                        ingredients: ["200ml plain yoghurt", "100ml water", "Pinch of salt", "30g mixed nuts"],
                        icon: "drop.fill", color: .teal)
                }
                return LocalSuggestion(
                    name: "Ayran & simit", description: "Classic Turkish pairing — tangy yoghurt drink with a sesame-crusted simit.",
                    mealType: MealType.snack.localizedName, calories: 240, protein: 10, prepTime: 2,
                    ingredients: ["1 simit (sesame ring bread)", "200ml ayran"],
                    icon: "drop.fill", color: .teal)
            }
            if remaining < 200 {
                return LocalSuggestion(
                    name: "Apple with almond butter", description: "A crisp apple with two tablespoons of natural almond butter.",
                    mealType: MealType.snack.localizedName, calories: 190, protein: 5, prepTime: 2,
                    ingredients: ["1 medium apple", "2 tbsp almond butter"],
                    icon: "leaf.fill", color: .red)
            }
            return LocalSuggestion(
                name: "Cottage cheese & seeds", description: "Low-fat cottage cheese topped with mixed seeds and cucumber.",
                mealType: MealType.snack.localizedName, calories: 180, protein: 20, prepTime: 2,
                ingredients: ["150g low-fat cottage cheese", "1 tbsp mixed seeds", "½ cucumber, sliced", "Pinch of paprika"],
                icon: "drop.fill", color: .teal)
        }

        // MARK: Dinner
        if isTurkish {
            if isKeto || avoidRedMeat {
                return LocalSuggestion(
                    name: "Balık (grilled sea bass)", description: "Whole sea bass grilled with olive oil, lemon, and herbs — light and rich in omega-3.",
                    mealType: MealType.dinner.localizedName, calories: min(remaining, 380), protein: 38, prepTime: 20,
                    ingredients: ["200g sea bass fillet", "2 tbsp olive oil", "Lemon", "Fresh dill", "Grilled vegetables"],
                    icon: "drop.fill", color: .indigo)
            }
            if isVegetarian || hasDiabetes {
                return LocalSuggestion(
                    name: "Karnıyarık (stuffed aubergine)", description: "Oven-baked aubergine stuffed with sautéed vegetables and tomato sauce.",
                    mealType: MealType.dinner.localizedName, calories: min(remaining, 340), protein: 10, prepTime: 30,
                    ingredients: ["2 medium aubergines", "1 onion", "2 tomatoes", "1 green pepper", "2 tbsp olive oil"],
                    icon: "fork.knife.circle.fill", color: .purple)
            }
            return LocalSuggestion(
                name: "Izgara köfte with cacık", description: "Grilled beef köfte with refreshing yoghurt-cucumber cacık and a simple salad.",
                mealType: MealType.dinner.localizedName, calories: min(remaining, 480), protein: 36, prepTime: 20,
                ingredients: ["150g ground beef (lean)", "1 cup yoghurt", "1 cucumber", "Fresh mint", "Tomato & onion salad"],
                icon: "fork.knife.circle.fill", color: SanaTheme.Color.primary)
        }
        if isKeto {
            return LocalSuggestion(
                name: "Baked salmon with asparagus", description: "Omega-3-rich salmon fillet with garlic-roasted asparagus.",
                mealType: MealType.dinner.localizedName, calories: min(remaining, 450), protein: 38, prepTime: 20,
                ingredients: ["180g salmon fillet", "200g asparagus", "2 tbsp olive oil", "2 garlic cloves", "Lemon & dill"],
                icon: "drop.fill", color: .indigo)
        }
        if hasDiabetes {
            return LocalSuggestion(
                name: "Baked chicken with roasted veg", description: "Low-GI oven chicken with a colourful mix of roasted non-starchy vegetables.",
                mealType: MealType.dinner.localizedName, calories: min(remaining, 420), protein: 40, prepTime: 30,
                ingredients: ["180g chicken breast", "1 courgette", "1 red pepper", "1 cup broccoli", "2 tbsp olive oil"],
                icon: "bolt.heart.fill", color: .green)
        }
        return LocalSuggestion(
            name: "Turkey & veggie stir-fry", description: "Lean turkey mince with colourful peppers and brown rice.",
            mealType: MealType.dinner.localizedName, calories: min(remaining, 500), protein: 36, prepTime: 15,
            ingredients: ["150g turkey mince", "½ cup brown rice", "1 red pepper", "1 cup broccoli", "Soy sauce & ginger"],
            icon: "fork.knife.circle.fill", color: SanaTheme.Color.primary)
    }
}
