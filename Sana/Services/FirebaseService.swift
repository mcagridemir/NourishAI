// Sana — FirebaseService.swift
// Centralises Firebase Analytics + Crashlytics so call sites stay clean
// and the rest of the app never imports Firebase directly.
import Foundation
internal import FirebaseCrashlytics
internal import FirebaseAnalytics

// MARK: - Analytics event names (keeps strings out of call sites)

enum SanaEvent {
    // Meals
    case mealLogged(calories: Int, source: MealSource)
    case mealDeleted
    case mealEdited
    case barcodeScanned(success: Bool)
    case photoAnalyzed(success: Bool)

    // Auth
    case signedIn(provider: String)
    case signedOut

    // Onboarding
    case onboardingStarted
    case onboardingCompleted
    case onboardingSkipped(step: String)

    // Features
    case coachMessageSent
    case mealPlanGenerated
    case insightsViewed
    case supplementAdded
    case waterLogged(ml: Double)
    case fastingStarted
    case fastingCompleted(hours: Double)

    // Subscriptions
    case paywallViewed
    case subscriptionStarted(productId: String)
    case subscriptionRestored

    // Streak
    case streakMilestone(days: Int)
    case streakBroken(days: Int)

    var name: String {
        switch self {
        case .mealLogged:           return "meal_logged"
        case .mealDeleted:          return "meal_deleted"
        case .mealEdited:           return "meal_edited"
        case .barcodeScanned:       return "barcode_scanned"
        case .photoAnalyzed:        return "photo_analyzed"
        case .signedIn:             return "sign_in"
        case .signedOut:            return "sign_out"
        case .onboardingStarted:    return "onboarding_started"
        case .onboardingCompleted:  return "onboarding_completed"
        case .onboardingSkipped:    return "onboarding_skipped"
        case .coachMessageSent:     return "coach_message_sent"
        case .mealPlanGenerated:    return "meal_plan_generated"
        case .insightsViewed:       return "insights_viewed"
        case .supplementAdded:      return "supplement_added"
        case .waterLogged:          return "water_logged"
        case .fastingStarted:       return "fasting_started"
        case .fastingCompleted:     return "fasting_completed"
        case .paywallViewed:        return "paywall_viewed"
        case .subscriptionStarted:  return "subscription_started"
        case .subscriptionRestored: return "subscription_restored"
        case .streakMilestone:      return "streak_milestone"
        case .streakBroken:         return "streak_broken"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case .mealLogged(let cal, let src): return ["calories": cal, "source": src.rawValue]
        case .barcodeScanned(let ok):       return ["success": ok]
        case .photoAnalyzed(let ok):        return ["success": ok]
        case .signedIn(let p):              return ["provider": p]
        case .onboardingSkipped(let s):     return ["step": s]
        case .waterLogged(let ml):          return ["ml": ml]
        case .fastingCompleted(let h):      return ["hours": h]
        case .subscriptionStarted(let id):  return ["product_id": id]
        case .streakMilestone(let d):       return ["days": d]
        case .streakBroken(let d):          return ["days": d]
        default:                            return [:]
        }
    }
}

enum MealSource: String {
    case manual, photo, barcode, coach, mealPlan = "meal_plan"
}

// MARK: - User properties

enum SanaUserProperty: String {
    case isPremium      = "is_premium"
    case authProvider   = "auth_provider"
    case appLanguage    = "app_language"
    case onboarded      = "onboarded"
}

// MARK: - FirebaseService

final class FirebaseService {

    static let shared = FirebaseService()
    private init() {}

    // MARK: - Analytics

    func log(_ event: SanaEvent) {
        Analytics.logEvent(event.name, parameters: event.parameters.isEmpty ? nil : event.parameters)
    }

    func setScreen(_ name: String, class screenClass: String? = nil) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: screenClass ?? name
        ])
    }

    func setUserProperty(_ value: String?, for property: SanaUserProperty) {
        Analytics.setUserProperty(value, forName: property.rawValue)
    }

    // MARK: - Crashlytics

    func setUserID(_ id: String?) {
        if let id {
            Crashlytics.crashlytics().setUserID(id)
        } else {
            Crashlytics.crashlytics().setUserID("")
        }
    }

    /// Attach a key–value pair visible in the Crashlytics issue dashboard.
    func setCustomValue(_ value: Any, key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    /// Log a breadcrumb message (visible in crash reports).
    func breadcrumb(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    /// Record a non-fatal error (shows in Crashlytics without crashing).
    func recordError(_ error: Error, context: String? = nil) {
        var userInfo: [String: Any] = [:]
        if let context { userInfo["context"] = context }
        let wrapped = (error as NSError).code != 0
            ? error
            : NSError(domain: "com.cagri.Sana", code: -1,
                      userInfo: [NSLocalizedDescriptionKey: error.localizedDescription].merging(userInfo) { $1 })
        Crashlytics.crashlytics().record(error: wrapped, userInfo: userInfo.isEmpty ? nil : userInfo)
    }

    /// Record a non-fatal event described by a plain string (no underlying Error).
    func recordNonFatal(_ message: String, code: Int = -1) {
        let error = NSError(domain: "com.cagri.Sana", code: code,
                            userInfo: [NSLocalizedDescriptionKey: message])
        Crashlytics.crashlytics().record(error: error)
    }

    #if DEBUG
    /// Force an immediate crash — for verifying the Crashlytics pipeline only.
    func forceCrash() {
        fatalError("Crashlytics test crash")
    }
    #endif
}
