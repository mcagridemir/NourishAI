// Sana — SanaTheme.swift
import SwiftUI
internal import UIKit

enum SanaTheme {

    // MARK: - Colors
    enum Color {
        static let primary        = SwiftUI.Color("PrimaryGreen")      // #2D9E75
        static let primaryLight   = SwiftUI.Color("PrimaryGreenLight") // #E1F5EE / #162922
        static let primaryDeep    = SwiftUI.Color("PrimaryDeep")       // #1F6F52 / #52C49B
        static let accent         = SwiftUI.Color("AccentOrange")      // #F0853A
        static let accentSoft     = SwiftUI.Color("AccentOrangeSoft")  // #FCEADC / #2C1A0E
        static let surface        = SwiftUI.Color("Surface")           // #FFFFFF / #1A1D1B
        static let elevated       = SwiftUI.Color("Elevated")          // #F4F1EB / #23272A
        static let softBg         = SwiftUI.Color("SoftBg")           // #F1EEE7 / #181B1A
        static let background     = SwiftUI.Color("Background")        // #FAF8F4 / #0E100E

        // Semantic status colors — use themed values, not system .green/.orange/.red,
        // so they honour dynamic color (dark mode) and match the design spec exactly.
        static let success        = primary                         // #2D9E75 green
        static let warning        = SwiftUI.Color("MacroCarbs")    // #E6A93E amber
        static let danger         = SwiftUI.Color("MacroFat")      // #E66B5C coral

        // Hairline borders — equivalent to rgba(20,22,25,0.07/0.12)
        static let hairline       = SwiftUI.Color(.label).opacity(0.07)
        static let hairlineStrong = SwiftUI.Color(.label).opacity(0.12)

        static func healthScore(_ score: Int) -> SwiftUI.Color {
            switch score {
            case 75...100: return primary
            case 50..<75:  return accent
            default:       return danger
            }
        }

        /// Background fill for a health score badge (tinted soft version of the score color).
        static func healthScoreBg(_ score: Int) -> SwiftUI.Color {
            switch score {
            case 75...100: return primaryLight
            case 50..<75:  return accentSoft
            default:       return danger.opacity(0.12)
            }
        }

        static func macro(_ macro: MacroType) -> SwiftUI.Color {
            switch macro {
            case .calories: return accent                          // orange #F0853A
            case .protein:  return SwiftUI.Color("MacroProtein")  // blue   #4A7CFF
            case .carbs:    return SwiftUI.Color("MacroCarbs")    // amber  #E6A93E
            case .fat:      return SwiftUI.Color("MacroFat")      // coral  #E66B5C
            case .fiber:    return SwiftUI.Color("MacroFiber")    // green  #2D9E75
            }
        }
    }

    // MARK: - Typography
    //
    // All fonts are wrapped in UIFontMetrics so they honour the user's
    // preferred text-size setting (Dynamic Type / Accessibility → Larger Text).
    // The base sizes are the design-spec values at the default (Large) size.
    enum Font {
        static func title(_ size: CGFloat = 28) -> SwiftUI.Font {
            scaled(size, weight: .bold, design: .rounded, relativeTo: .largeTitle)
        }
        static func headline(_ size: CGFloat = 17) -> SwiftUI.Font {
            scaled(size, weight: .semibold, design: .rounded, relativeTo: .headline)
        }
        static func body(_ size: CGFloat = 15) -> SwiftUI.Font {
            scaled(size, weight: .regular, design: .default, relativeTo: .body)
        }
        static func caption(_ size: CGFloat = 12) -> SwiftUI.Font {
            scaled(size, weight: .medium, design: .default, relativeTo: .caption1)
        }
        static func mono(_ size: CGFloat = 14) -> SwiftUI.Font {
            scaled(size, weight: .regular, design: .monospaced, relativeTo: .body)
        }
        // numeric uses the built-in semantic style — already Dynamic Type aware
        static let numeric = SwiftUI.Font.system(.title2, design: .rounded, weight: .bold)

        // MARK: Private helper
        private static func scaled(
            _ size: CGFloat,
            weight: UIFont.Weight,
            design: UIFontDescriptor.SystemDesign,
            relativeTo style: UIFont.TextStyle
        ) -> SwiftUI.Font {
            // Build a descriptor at the default (Large) size, apply design + weight
            let base = UIFontDescriptor.preferredFontDescriptor(withTextStyle: style)
            let designed = base.withDesign(design) ?? base
            let weighted = designed.addingAttributes([
                .traits: [UIFontDescriptor.TraitKey.weight: weight]
            ])
            let uiFont = UIFont(descriptor: weighted, size: size)
            // Wrap in UIFontMetrics so it scales with the user's text-size preference
            let scaled = UIFontMetrics(forTextStyle: style).scaledFont(for: uiFont)
            return SwiftUI.Font(scaled)
        }
    }

    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat   = 4
        static let sm: CGFloat   = 8
        static let md: CGFloat   = 12
        static let lg: CGFloat   = 16
        static let xl: CGFloat   = 20
        static let xxl: CGFloat  = 24
        static let xxxl: CGFloat = 32
        static let huge: CGFloat = 48
    }

    // MARK: - Corner radius
    enum Radius {
        static let sm: CGFloat   = 10
        static let md: CGFloat   = 14
        static let lg: CGFloat   = 22
        static let xl: CGFloat   = 28
        static let pill: CGFloat = 999
    }

    // MARK: - Animations
    enum Animation {
        static var snappy: SwiftUI.Animation {
            UIAccessibility.isReduceMotionEnabled
                ? .linear(duration: 0.15)
                : .spring(response: 0.35, dampingFraction: 0.8)
        }
        static var smooth: SwiftUI.Animation {
            UIAccessibility.isReduceMotionEnabled
                ? .linear(duration: 0.15)
                : .easeInOut(duration: 0.3)
        }
        static var slow: SwiftUI.Animation {
            UIAccessibility.isReduceMotionEnabled
                ? .linear(duration: 0.15)
                : .easeInOut(duration: 0.6)
        }
        /// Springy bounce — used on macro rings and progress arcs so they ease
        /// slightly past their target then settle back (design spec: response 0.8, damping 0.6).
        static var bouncy: SwiftUI.Animation {
            UIAccessibility.isReduceMotionEnabled
                ? .linear(duration: 0.2)
                : .spring(response: 0.8, dampingFraction: 0.6)
        }
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
        case .calories: return SanaTheme.Color.accent              // orange
        case .protein:  return SwiftUI.Color("MacroProtein")       // blue
        case .carbs:    return SwiftUI.Color("MacroCarbs")         // amber
        case .fat:      return SwiftUI.Color("MacroFat")           // coral
        case .fiber:    return SwiftUI.Color("MacroFiber")         // green
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
            .padding(SanaTheme.Spacing.md)
            .background(SanaTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
            // Design spec: 0.5px hairline border on all cards
            .overlay(
                RoundedRectangle(cornerRadius: SanaTheme.Radius.lg)
                    .stroke(SanaTheme.Color.hairline, lineWidth: 0.5)
            )
    }
}

struct NourishButtonStyle: ButtonStyle {
    var isPrimary: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SanaTheme.Font.headline())
            .foregroundStyle(isPrimary ? .white : SanaTheme.Color.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isPrimary ? SanaTheme.Color.primary : SanaTheme.Color.primaryLight)
            // Design spec: primary buttons are full-pill (radius 999), not just xl (28)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(SanaTheme.Animation.snappy, value: configuration.isPressed)
    }
}

extension View {
    func nourishCard() -> some View { modifier(NourishCardStyle()) }
}
