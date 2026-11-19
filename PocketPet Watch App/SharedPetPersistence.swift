import Foundation

enum PocketPetStorage {
    static let appGroupIdentifier = "group.ugurmetinkarabulut.PocketPet"
    static let stateKey = "pocketPet.state"
    static let onboardingKey = "pocketPet.hasCompletedOnboarding"

    static func loadState(from defaults: UserDefaults) -> PetState? {
        guard let data = defaults.data(forKey: stateKey) else { return nil }
        return try? JSONDecoder().decode(PetState.self, from: data)
    }

    static func saveState(_ state: PetState, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: stateKey)
    }

    static func appGroupDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    static func migratedAppDefaults(
        legacyDefaults: UserDefaults = .standard
    ) -> UserDefaults {
        guard let sharedDefaults = appGroupDefaults() else {
            return legacyDefaults
        }

        migrateIfNeeded(from: legacyDefaults, to: sharedDefaults)
        return sharedDefaults
    }

    static func migrateIfNeeded(
        from legacyDefaults: UserDefaults,
        to sharedDefaults: UserDefaults
    ) {
        guard sharedDefaults.data(forKey: stateKey) == nil else { return }

        if let stateData = legacyDefaults.data(forKey: stateKey) {
            sharedDefaults.set(stateData, forKey: stateKey)
        }
        if let onboarding = legacyDefaults.object(forKey: onboardingKey) {
            sharedDefaults.set(onboarding, forKey: onboardingKey)
        }
    }
}
