// NourishAI — HealthKitService.swift
import Foundation
import HealthKit
internal import Combine

@MainActor
final class HealthKitService: ObservableObject {

    static let shared = HealthKitService()
    private let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var todaySteps: Int = 0
    @Published var todayActiveCalories: Double = 0
    @Published var lastNightSleep: Double = 0   // hours
    @Published var currentWeight: Double = 0     // kg
    @Published var heartRateResting: Double = 0

    private let readTypes: Set<HKObjectType> = {
        var types = Set<HKObjectType>()
        let ids: [HKQuantityTypeIdentifier] = [
            .stepCount, .activeEnergyBurned, .bodyMass,
            .restingHeartRate, .dietaryEnergyConsumed,
            .dietaryProtein, .dietaryCarbohydrates, .dietaryFatTotal
        ]
        ids.compactMap { HKQuantityType.quantityType(forIdentifier: $0) }.forEach { types.insert($0) }
        if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(sleepType) }
        return types
    }()

    private let writeTypes: Set<HKSampleType> = {
        let ids: [HKQuantityTypeIdentifier] = [
            .dietaryEnergyConsumed, .dietaryProtein,
            .dietaryCarbohydrates, .dietaryFatTotal, .dietaryFiber
        ]
        return Set(ids.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        isAuthorized = true
        await refreshAll()
    }

    func refreshAll() async {
        async let steps = fetchSteps()
        async let active = fetchActiveCalories()
        async let sleep = fetchSleep()
        async let weight = fetchWeight()
        async let hr = fetchRestingHeartRate()

        todaySteps = await steps
        todayActiveCalories = await active
        lastNightSleep = await sleep
        currentWeight = await weight
        heartRateResting = await hr
    }

    // MARK: - Write nutrition data back to Health app

    func logMeal(_ entry: MealEntry) async throws {
        guard isAuthorized else { return }
        let now = entry.loggedAt
        var samples = [HKQuantitySample]()

        let macros: [(HKQuantityTypeIdentifier, Double, HKUnit)] = [
            (.dietaryEnergyConsumed, Double(entry.calories), .kilocalorie()),
            (.dietaryProtein, entry.protein, .gram()),
            (.dietaryCarbohydrates, entry.carbohydrates, .gram()),
            (.dietaryFatTotal, entry.fat, .gram()),
            (.dietaryFiber, entry.fiber, .gram())
        ]
        for (id, value, unit) in macros {
            guard let type = HKQuantityType.quantityType(forIdentifier: id) else { continue }
            let sample = HKQuantitySample(type: type, quantity: HKQuantity(unit: unit, doubleValue: value),
                                          start: now, end: now)
            samples.append(sample)
        }
        try await store.save(samples)
    }

    // MARK: - Private fetchers

    private func fetchSteps() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)
        return await fetchSum(type: type, unit: .count(), start: start, end: .now).map(Int.init) ?? 0
    }

    private func fetchActiveCalories() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)
        return await fetchSum(type: type, unit: .kilocalorie(), start: start, end: .now) ?? 0
    }

    private func fetchWeight() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .bodyMass) else { return 0 }
        return await fetchMostRecent(type: type, unit: HKUnit.gramUnit(with: .kilo)) ?? 0
    }

    private func fetchRestingHeartRate() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return 0 }
        return await fetchMostRecent(type: type, unit: HKUnit.count().unitDivided(by: .minute())) ?? 0
    }

    private func fetchSleep() async -> Double {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0 }
        let start = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: .now)) ?? .now
        let predicate = HKQuery.predicateForSamples(withStart: start, end: .now)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 20, sortDescriptors: nil) { _, samples, _ in
                let hours = (samples as? [HKCategorySample])?.filter {
                    $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
                    $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue
                }.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } ?? 0
                continuation.resume(returning: hours / 3600)
            }
            store.execute(query)
        }
    }

    private func fetchSum(type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func fetchMostRecent(type: HKQuantityType, unit: HKUnit) async -> Double? {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let val = (samples?.first as? HKQuantitySample)?.quantity.doubleValue(for: unit)
                continuation.resume(returning: val)
            }
            store.execute(query)
        }
    }
}
