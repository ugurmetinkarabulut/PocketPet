import Foundation
import UserNotifications

enum PetNeed: String, CaseIterable, Codable {
    case hunger
    case happiness
    case energy

    var notificationIdentifier: String {
        "pocketPet.need.\(rawValue)"
    }

    func title(petName: String) -> String {
        switch self {
        case .hunger:
            return "\(petName) is hungry"
        case .happiness:
            return "\(petName) misses you"
        case .energy:
            return "\(petName) needs a rest"
        }
    }

    var body: String {
        switch self {
        case .hunger:
            return "A little snack would hit the spot!"
        case .happiness:
            return "A quick pet or play would cheer me up!"
        case .energy:
            return "I’m getting sleepy. Let’s take it easy!"
        }
    }
}

enum PetNotificationConstants {
    // Hunger rises as the pet gets hungrier; happiness and energy fall.
    static let criticalHunger = 80.0
    static let criticalHappiness = 20.0
    static let criticalEnergy = 20.0

    static let recoveredHunger = 60.0
    static let recoveredHappiness = 40.0
    static let recoveredEnergy = 40.0

    static let notificationCooldown: TimeInterval = 12 * 60 * 60
    static let immediateNotificationDelay: TimeInterval = 1
    static let equivalentScheduleTolerance: TimeInterval = 60

}

struct PetNotificationCheckpoint: Codable, Equatable {
    var isEligible = true
    var lastNotificationDate: Date?
    var scheduledDate: Date?
}

struct PetNotificationPlan: Equatable {
    enum Action: Equatable {
        case keepPending
        case cancelPending
        case schedule(Date)
    }

    let checkpoint: PetNotificationCheckpoint
    let action: Action
}

enum PetNotificationPolicy {
    static func plan(
        for need: PetNeed,
        state: PetState,
        checkpoint originalCheckpoint: PetNotificationCheckpoint,
        now: Date
    ) -> PetNotificationPlan {
        var checkpoint = originalCheckpoint

        if let scheduledDate = checkpoint.scheduledDate, scheduledDate <= now {
            checkpoint.isEligible = false
            checkpoint.lastNotificationDate = scheduledDate
            checkpoint.scheduledDate = nil
        }

        if isRecovered(need, state: state) {
            checkpoint.isEligible = true
        }

        guard checkpoint.isEligible else {
            return PetNotificationPlan(
                checkpoint: checkpoint,
                action: .cancelPending
            )
        }

        let cooldownEnd = checkpoint.lastNotificationDate?.addingTimeInterval(
            PetNotificationConstants.notificationCooldown
        ) ?? now

        if isCritical(need, state: state) {
            let notificationDate = max(
                now.addingTimeInterval(
                    PetNotificationConstants.immediateNotificationDelay
                ),
                cooldownEnd
            )

            if let scheduledDate = checkpoint.scheduledDate,
               abs(scheduledDate.timeIntervalSince(notificationDate))
                <= PetNotificationConstants.equivalentScheduleTolerance {
                return PetNotificationPlan(
                    checkpoint: checkpoint,
                    action: .keepPending
                )
            }

            checkpoint.scheduledDate = notificationDate
            return PetNotificationPlan(
                checkpoint: checkpoint,
                action: .schedule(notificationDate)
            )
        }

        let thresholdDate = projectedCriticalDate(
            for: need,
            state: state,
            now: now
        )
        let notificationDate = max(thresholdDate, cooldownEnd)

        if let scheduledDate = checkpoint.scheduledDate,
           abs(scheduledDate.timeIntervalSince(notificationDate))
            <= PetNotificationConstants.equivalentScheduleTolerance {
            return PetNotificationPlan(
                checkpoint: checkpoint,
                action: .keepPending
            )
        }

        checkpoint.scheduledDate = notificationDate
        return PetNotificationPlan(
            checkpoint: checkpoint,
            action: .schedule(notificationDate)
        )
    }

    private static func isCritical(_ need: PetNeed, state: PetState) -> Bool {
        switch need {
        case .hunger:
            return state.hunger >= PetNotificationConstants.criticalHunger
        case .happiness:
            return state.happiness <= PetNotificationConstants.criticalHappiness
        case .energy:
            return state.energy <= PetNotificationConstants.criticalEnergy
        }
    }

    private static func isRecovered(_ need: PetNeed, state: PetState) -> Bool {
        switch need {
        case .hunger:
            return state.hunger <= PetNotificationConstants.recoveredHunger
        case .happiness:
            return state.happiness >= PetNotificationConstants.recoveredHappiness
        case .energy:
            return state.energy >= PetNotificationConstants.recoveredEnergy
        }
    }

    private static func projectedCriticalDate(
        for need: PetNeed,
        state: PetState,
        now: Date
    ) -> Date {
        let hoursUntilCritical: Double

        switch need {
        case .hunger:
            hoursUntilCritical =
                (PetNotificationConstants.criticalHunger - state.hunger)
                / PetDecayConstants.hungerPerHour
        case .happiness:
            hoursUntilCritical =
                (state.happiness - PetNotificationConstants.criticalHappiness)
                / PetDecayConstants.happinessPerHour
        case .energy:
            hoursUntilCritical =
                (state.energy - PetNotificationConstants.criticalEnergy)
                / PetDecayConstants.energyPerHour
        }

        return now.addingTimeInterval(max(0, hoursUntilCritical) * 60 * 60)
    }
}

@MainActor
final class PetNotificationManager {
    private let center: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let checkpointKey = "pocketPet.notificationCheckpoints"

    init(
        center: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.center = center
        self.defaults = defaults
    }

    func start(for state: PetState, at date: Date = .now) async {
        let settings = await center.notificationSettings()
        var isAuthorized = Self.isAuthorized(settings.authorizationStatus)

        if settings.authorizationStatus == .notDetermined {
            isAuthorized = (try? await center.requestAuthorization(
                options: [.alert, .sound]
            )) ?? false
        }

        guard isAuthorized else {
            center.removePendingNotificationRequests(
                withIdentifiers: PetNeed.allCases.map(\.notificationIdentifier)
            )
            return
        }

        await update(for: state, at: date)
    }

    func update(for state: PetState, at date: Date = .now) async {
        let settings = await center.notificationSettings()
        guard Self.isAuthorized(settings.authorizationStatus) else { return }

        var checkpoints = loadCheckpoints()

        for need in PetNeed.allCases {
            let plan = PetNotificationPolicy.plan(
                for: need,
                state: state,
                checkpoint: checkpoints[need] ?? PetNotificationCheckpoint(),
                now: date
            )
            checkpoints[need] = plan.checkpoint

            switch plan.action {
            case .keepPending:
                break
            case .cancelPending:
                center.removePendingNotificationRequests(
                    withIdentifiers: [need.notificationIdentifier]
                )
            case .schedule(let notificationDate):
                center.removePendingNotificationRequests(
                    withIdentifiers: [need.notificationIdentifier]
                )
                let content = UNMutableNotificationContent()
                content.title = need.title(petName: state.name)
                content.body = need.body
                content.sound = .default

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: max(
                        PetNotificationConstants.immediateNotificationDelay,
                        notificationDate.timeIntervalSince(date)
                    ),
                    repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: need.notificationIdentifier,
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }

        saveCheckpoints(checkpoints)
    }

    private static func isAuthorized(
        _ status: UNAuthorizationStatus
    ) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func loadCheckpoints() -> [PetNeed: PetNotificationCheckpoint] {
        guard let data = defaults.data(forKey: checkpointKey) else { return [:] }
        return (try? JSONDecoder().decode(
            [PetNeed: PetNotificationCheckpoint].self,
            from: data
        )) ?? [:]
    }

    private func saveCheckpoints(
        _ checkpoints: [PetNeed: PetNotificationCheckpoint]
    ) {
        guard let data = try? JSONEncoder().encode(checkpoints) else { return }
        defaults.set(data, forKey: checkpointKey)
    }
}
