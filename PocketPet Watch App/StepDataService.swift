import Foundation
import HealthKit
import Observation

struct DailyStepSnapshot: Equatable {
    let count: Int
    let hasData: Bool
}

protocol StepDataProviding {
    var isAvailable: Bool { get }
    func requestReadAuthorization() async throws
    func todayStepCount(at date: Date) async throws -> DailyStepSnapshot
}

struct HealthKitStepDataService: StepDataProviding {
    private let healthStore: HKHealthStore

    init() {
        healthStore = HKHealthStore()
    }

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestReadAuthorization() async throws {
        guard isAvailable else { throw StepDataError.healthDataUnavailable }

        let stepType = HKQuantityType(.stepCount)
        try await healthStore.requestAuthorization(
            toShare: [],
            read: [stepType]
        )
    }

    func todayStepCount(at date: Date = .now) async throws -> DailyStepSnapshot {
        guard isAvailable else { throw StepDataError.healthDataUnavailable }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: date)
        let samplePredicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: date,
            options: .strictStartDate
        )
        let stepType = HKQuantityType(.stepCount)
        let stepsToday = HKSamplePredicate.quantitySample(
            type: stepType,
            predicate: samplePredicate
        )
        let query = HKStatisticsQueryDescriptor(
            predicate: stepsToday,
            options: .cumulativeSum
        )
        let quantity = try await query.result(for: healthStore)?.sumQuantity()
        let count = quantity?.doubleValue(for: .count()) ?? 0

        return DailyStepSnapshot(
            count: max(0, Int(count.rounded(.down))),
            hasData: quantity != nil
        )
    }
}

enum StepDataError: Error {
    case healthDataUnavailable
}

struct PreviewStepDataService: StepDataProviding {
    var isAvailable: Bool { true }

    func requestReadAuthorization() async throws {}

    func todayStepCount(at date: Date) async throws -> DailyStepSnapshot {
        DailyStepSnapshot(count: 4_200, hasData: true)
    }
}

enum StepIndicatorState: Equatable {
    case needsAuthorization
    case loading
    case available(stepCount: Int, earnedXP: Int)
    case noAccess
    case unavailable
    case failed
}

@MainActor
@Observable
final class StepProgressController {
    private(set) var state: StepIndicatorState

    private let service: any StepDataProviding
    private let defaults: UserDefaults
    private let authorizationRequestedKey = "pocketPet.stepsAuthorizationRequested"
    private var lastRefreshDate: Date?

    convenience init() {
        self.init(
            service: HealthKitStepDataService(),
            defaults: .standard
        )
    }

    init(service: any StepDataProviding, defaults: UserDefaults) {
        self.service = service
        self.defaults = defaults
        state = defaults.bool(forKey: authorizationRequestedKey)
            ? .loading
            : .needsAuthorization
    }

    func requestAccessAndRefresh(
        petStore: PetStateStore,
        at date: Date = .now
    ) async {
        guard service.isAvailable else {
            state = .unavailable
            return
        }

        state = .loading

        do {
            try await service.requestReadAuthorization()
            defaults.set(true, forKey: authorizationRequestedKey)
            await refresh(petStore: petStore, at: date, force: true)
        } catch StepDataError.healthDataUnavailable {
            state = .unavailable
        } catch {
            state = .failed
        }
    }

    func refresh(
        petStore: PetStateStore,
        at date: Date = .now,
        force: Bool = false
    ) async {
        guard service.isAvailable else {
            state = .unavailable
            return
        }

        guard defaults.bool(forKey: authorizationRequestedKey) else {
            state = .needsAuthorization
            return
        }

        if !force,
           let lastRefreshDate,
           date.timeIntervalSince(lastRefreshDate) < 60 {
            return
        }

        lastRefreshDate = date
        state = .loading

        do {
            let snapshot = try await service.todayStepCount(at: date)
            guard snapshot.hasData else {
                state = .noAccess
                return
            }

            let earnedXP = petStore.updateTodayStepsAndRewardXP(
                snapshot.count,
                at: date
            )
            state = .available(
                stepCount: snapshot.count,
                earnedXP: earnedXP
            )
        } catch StepDataError.healthDataUnavailable {
            state = .unavailable
        } catch let error as HKError where error.code == .errorAuthorizationDenied {
            state = .noAccess
        } catch {
            state = .failed
        }
    }
}
