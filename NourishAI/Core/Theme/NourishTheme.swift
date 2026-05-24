// NourishAI — NourishTheme.swift
import SwiftUI

enum NourishTheme {

    // MARK: - Colors
    enum Color {
        static let primary      = SwiftUI.Color("PrimaryGreen")     // #2D9E75
        static let primaryLight = SwiftUI.Color("PrimaryGreenLight") // #E1F5EE
        static let accent       = SwiftUI.Color("AccentOrange")      // #F0853A
        static let surface      = SwiftUI.Color("Surface")
        static let background   = SwiftUI.Color("Background")

        static let success      = SwiftUI.Color.green
        static let warning      = SwiftUI.Color.orange
        static let danger       = SwiftUI.Color.red

        static func healthScore(_ score: Int) -> SwiftUI.Color {
            switch score {
            case 75...100: return .green
            case 50..<75:  return .orange
            default:       return .red
            }
        }

        static func macro(_ macro: MacroType) -> SwiftUI.Color {
            switch macro {
            case .calories: return .orange
            case .protein:  return SwiftUI.Color("MacroProtein")   // blue
            case .carbs:    return SwiftUI.Color("MacroCarbs")     // amber
            case .fat:      return SwiftUI.Color("MacroFat")       // coral
            case .fiber:    return SwiftUI.Color("MacroFiber")     // green
            }
        }
    }

    // MARK: - Typography
    enum Font {
        static func title(_ size: CGFloat = 28) -> SwiftUI.Font { .system(size: size, weight: .bold, design: .rounded) }
        static func headline(_ size: CGFloat = 17) -> SwiftUI.Font { .system(size: size, weight: .semibold, design: .rounded) }
        static func body(_ size: CGFloat = 15) -> SwiftUI.Font { .system(size: size, weight: .regular, design: .default) }
        static func caption(_ size: CGFloat = 12) -> SwiftUI.Font { .system(size: size, weight: .medium, design: .default) }
        static func mono(_ size: CGFloat = 14) -> SwiftUI.Font { .system(size: size, weight: .regular, design: .monospaced) }
        static let numeric = SwiftUI.Font.system(.title2, design: .rounded, weight: .bold)
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }

    // MARK: - Animations
    enum Animation {
        static let snappy = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow   = SwiftUI.Animation.easeInOut(duration: 0.6)
    }
}

enum MacroType: String, CaseIterable, Identifiable {
    case calories = "Calories"
    case protein  = "Protein"
    case carbs    = "Carbs"
    case fat      = "Fat"
    case fiber    = "Fiber"

    var id: String { rawValue }

    /// Localized display name — use this in UI instead of `rawValue`.
    var localizedName: String { NSLocalizedString(rawValue, comment: "") }

    var unit: String {
        switch self {
        case .calories: return "kcal"
        default: return "g"
        }
    }

    var icon: String {
        switch self {
        case .calories: return "flame.fill"
        case .protein:  return "bolt.fill"
        case .carbs:    return "leaf.fill"
        case .fat:      return "drop.fill"
        case .fiber:    return "list.bullet.circle.fill"
        }
    }

    /// Alias for `detailColor` — convenience for inline use.
    var color: SwiftUI.Color { detailColor }

    var detailColor: SwiftUI.Color {
        switch self {
        case .calories: return .orange
        case .protein:  return SwiftUI.Color("MacroProtein")
        case .carbs:    return SwiftUI.Color("MacroCarbs")
        case .fat:      return SwiftUI.Color("MacroFat")
        case .fiber:    return SwiftUI.Color("MacroFiber")
        }
    }

    func value(of meal: MealEntry) -> Double {
        switch self {
        case .calories: return Double(meal.calories)
        case .protein:  return meal.protein
        case .carbs:    return meal.carbohydrates
        case .fat:      return meal.fat
        case .fiber:    return meal.fiber
        }
    }

    func target(for user: User) -> Double {
        switch self {
        case .calories: return Double(user.dailyCalorieTarget)
        case .protein:  return user.dailyProteinTarget
        case .carbs:    return user.dailyCarbTarget
        case .fat:      return user.dailyFatTarget
        case .fiber:    return user.dailyFiberTarget
        }
    }
}

// MARK: - View modifiers

struct NourishCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(NourishTheme.Spacing.md)
            .background(NourishTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg))
    }
}

struct NourishButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(NourishTheme.Font.headline())
            .foregroundStyle(isPrimary ? .white : NourishTheme.Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isPrimary ? NourishTheme.Color.primary : NourishTheme.Color.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.xl))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(NourishTheme.Animation.snappy, value: configuration.isPressed)
    }
}

extension View {
    func nourishCard() -> some View { modifier(NourishCardStyle()) }
}
