import Foundation
import Observation
import WidgetKit

protocol PetStatePersisting {
    func load() -> PetState?
    func save(_ state: PetState)
    func loadOnboardingCompletion() -> Bool?
    func saveOnboardingCompletion(_ isCompleted: Bool)
}

struct UserDefaultsPetStatePersistence: PetStatePersisting {
    private let defaults: UserDefaults

    init() {
        defaults = PocketPetStorage.migratedAppDefaults()
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> PetState? {
        PocketPetStorage.loadState(from: defaults)
    }

    func save(_ state: PetState) {
        PocketPetStorage.saveState(state, to: defaults)
    }

    func loadOnboardingCompletion() -> Bool? {
        defaults.object(forKey: PocketPetStorage.onboardingKey) as? Bool
    }

    func saveOnboardingCompletion(_ isCompleted: Bool) {
        defaults.set(isCompleted, forKey: PocketPetStorage.onboardingKey)
    }
}

struct PreviewPetStatePersistence: PetStatePersisting {
    let onboardingCompleted: Bool

    init(onboardingCompleted: Bool = true) {
        self.onboardingCompleted = onboardingCompleted
    }

    func load() -> PetState? { .initial }
    func save(_ state: PetState) {}
    func loadOnboardingCompletion() -> Bool? { onboardingCompleted }
    func saveOnboardingCompletion(_ isCompleted: Bool) {}
}

@MainActor
@Observable
final class PetStateStore {
    private(set) var state: PetState
    private(set) var hasCompletedOnboarding: Bool
    private let persistence: any PetStatePersisting
    private weak var snapshotSender: (any PetSnapshotSending)?
    private var todayStepCount: Int?

    convenience init(now: Date = .now) {
        self.init(persistence: UserDefaultsPetStatePersistence(), now: now)
    }

    func connectSnapshotSender(_ sender: any PetSnapshotSending) {
        snapshotSender = sender
        sendLatestSnapshot()
    }

    init(persistence: any PetStatePersisting, now: Date = .now) {
        self.persistence = persistence
        let restoredState = persistence.load()
        state = restoredState ?? .initial
        if let savedCompletion = persistence.loadOnboardingCompletion() {
            hasCompletedOnboarding = savedCompletion
        } else {
            // Existing saved pets predate onboarding and should not see it.
            hasCompletedOnboarding = restoredState != nil
            persistence.saveOnboardingCompletion(hasCompletedOnboarding)
        }
        state.applyDecay(at: now)
        persistence.save(state)
    }

    @discardableResult
    func completeOnboarding(petName: String) -> Bool {
        guard let validatedName = PetNameRules.validatedName(petName) else {
            return false
        }

        state.name = validatedName
        hasCompletedOnboarding = true
        persistence.save(state)
        persistence.saveOnboardingCompletion(true)
        reloadComplication()
        sendLatestSnapshot()
        return true
    }

    @discardableResult
    func renamePet(_ petName: String, at date: Date = .now) -> PetSnapshot? {
        guard let validatedName = PetNameRules.validatedName(petName) else {
            return nil
        }

        state.name = validatedName
        persistence.save(state)
        reloadComplication()
        return sendLatestSnapshot(at: date)
    }

#if DEBUG
    func resetOnboarding() {
        hasCompletedOnboarding = false
        persistence.saveOnboardingCompletion(false)
    }
#endif

    func refresh(at date: Date = .now) {
        state.applyDecay(at: date)
        persistence.save(state)
        sendLatestSnapshot(at: date)
    }

    @discardableResult
    func feed(_ food: Food, at date: Date = .now) -> PetSnapshot {
        state.feed(food)
        persistence.save(state)
        reloadComplication()
        return sendLatestSnapshot(at: date)
    }

    @discardableResult
    func play(at date: Date = .now) -> PetSnapshot {
        state.play()
        persistence.save(state)
        reloadComplication()
        return sendLatestSnapshot(at: date)
    }

    @discardableResult
    func pet(at date: Date = .now) -> PetSnapshot {
        state.pet()
        persistence.save(state)
        reloadComplication()
        return sendLatestSnapshot(at: date)
    }

    @discardableResult
    func rewardXP(forTodayStepCount stepCount: Int, at date: Date = .now) -> Int {
        let earnedXP = state.rewardXP(forTodayStepCount: stepCount, at: date)
        persistence.save(state)
        sendLatestSnapshot(at: date)
        return earnedXP
    }

    @discardableResult
    func updateTodayStepsAndRewardXP(
        _ stepCount: Int,
        at date: Date = .now
    ) -> Int {
        todayStepCount = max(0, stepCount)
        let earnedXP = state.rewardXP(forTodayStepCount: stepCount, at: date)
        persistence.save(state)
        sendLatestSnapshot(at: date)
        return earnedXP
    }

    @discardableResult
    func sendLatestSnapshot(at date: Date = .now) -> PetSnapshot {
        let snapshot = PetSnapshot(
            state: state,
            todayStepCount: todayStepCount,
            timestamp: date
        )
        return snapshotSender?.send(snapshot) ?? snapshot
    }

    private func reloadComplication() {
        WidgetCenter.shared.reloadTimelines(ofKind: "PocketPetComplication")
    }
}
