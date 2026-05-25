// Sana — LiveActivityService.swift
import ActivityKit
import Foundation

// MARK: - Fasting Live Activity (attributes mirrored from widget target)

struct FastingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var targetSeconds: Double
        var isComplete: Bool
        var zone: String
    }
}

// MARK: - Fasting Live Activity Service

@MainActor
final class FastingLiveActivityService {
    static let shared = FastingLiveActivityService()
    private var activity: Activity<FastingActivityAttributes>?
    private init() {}

    func start(startDate: Date, targetSeconds: Double, zone: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = FastingActivityAttributes.ContentState(
            startDate: startDate,
            targetSeconds: targetSeconds,
            isComplete: false,
            zone: zone
        )
        let content = ActivityContent(state: state, staleDate: startDate.addingTimeInterval(targetSeconds + 3600))
        activity = try? Activity.request(
            attributes: FastingActivityAttributes(),
            content: content,
            pushType: nil
        )
    }

    func update(zone: String) {
        guard let activity else { return }
        Task {
            let updated = FastingActivityAttributes.ContentState(
                startDate: activity.content.state.startDate,
                targetSeconds: activity.content.state.targetSeconds,
                isComplete: false,
                zone: zone
            )
            await activity.update(ActivityContent(state: updated, staleDate: nil))
        }
    }

    func complete() {
        guard let activity else { return }
        Task {
            let state = activity.content.state
            let done = FastingActivityAttributes.ContentState(
                startDate: state.startDate,
                targetSeconds: state.targetSeconds,
                isComplete: true,
                zone: "Fast complete! 🎉"
            )
            await activity.update(ActivityContent(state: done, staleDate: nil))
            try? await Task.sleep(for: .seconds(5))
            await activity.end(ActivityContent(state: done, staleDate: nil), dismissalPolicy: .after(.now + 30))
            self.activity = nil
        }
    }

    func end() {
        Task {
            await activity?.end(nil, dismissalPolicy: .immediate)
            activity = nil
        }
    }
}

// MARK: - Nutrition Live Activity Service

@MainActor
final class LiveActivityService {

    static let shared = LiveActivityService()
    private var currentActivity: Activity<SanaActivityAttributes>?

    private init() {}

    func startOrUpdate(user: User) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = makeState(for: user)
        let staleDate = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)

        if let activity = currentActivity {
            Task {
                await activity.update(ActivityContent(state: state, staleDate: staleDate))
            }
        } else {
            let attrs = SanaActivityAttributes(userName: user.name)
            currentActivity = try? Activity.request(
                attributes: attrs,
                content: ActivityContent(state: state, staleDate: staleDate),
                pushType: nil
            )
        }
    }

    func end() {
        Task {
            await currentActivity?.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }

    private func makeState(for user: User) -> SanaActivityAttributes.ContentState {
        SanaActivityAttributes.ContentState(
            calories: user.todayCalories,
            calorieTarget: user.dailyCalorieTarget,
            waterMl: user.todayWaterMl,
            waterGoalMl: user.dailyWaterGoalMl,
            protein: user.todayProtein,
            proteinTarget: user.dailyProteinTarget,
            mealCount: user.todayMealCount,
            streak: user.currentStreak,
            isImperial: user.unitSystem == .imperial
        )
    }
}
