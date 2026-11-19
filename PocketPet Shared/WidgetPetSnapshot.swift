import Foundation

enum PocketPetWidgetConfiguration {
    static let appGroupIdentifier = "group.ugurmetinkarabulut.PocketPet"
    static let kind = "PocketPetHomeWidget"
}

struct WidgetPetSnapshot: Codable, Equatable, Sendable {
    let version: Int64
    let timestamp: Date
    let petName: String
    let level: Int
    let xp: Int
    let hunger: Double
    let happiness: Double
    let energy: Double
    let visualState: String
    let todayStepCount: Int?

    init(snapshot: PetSnapshot) {
        version = snapshot.version
        timestamp = snapshot.timestamp
        petName = snapshot.petName
        level = snapshot.level
        xp = snapshot.xp
        hunger = snapshot.hunger
        happiness = snapshot.happiness
        energy = snapshot.energy
        visualState = snapshot.visualState
        todayStepCount = snapshot.todayStepCount
    }
}

protocol WidgetSnapshotPersisting {
    func load() -> WidgetPetSnapshot?

    @discardableResult
    func saveIfNewer(_ snapshot: WidgetPetSnapshot) -> Bool
}

struct UserDefaultsWidgetSnapshotStore: WidgetSnapshotPersisting {
    private static let key = "pocketPet.iPhoneWidgetSnapshot"
    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    static func appGroupStore() -> Self? {
        guard let defaults = UserDefaults(
            suiteName: PocketPetWidgetConfiguration.appGroupIdentifier
        ) else { return nil }
        return Self(defaults: defaults)
    }

    func load() -> WidgetPetSnapshot? {
        guard
            let data = defaults.data(forKey: Self.key),
            let snapshot = try? PropertyListDecoder().decode(
                WidgetPetSnapshot.self,
                from: data
            )
        else { return nil }
        return snapshot
    }

    @discardableResult
    func saveIfNewer(_ snapshot: WidgetPetSnapshot) -> Bool {
        if let current = load(), !snapshot.isNewer(than: current) {
            return false
        }
        guard let data = try? PropertyListEncoder().encode(snapshot) else {
            return false
        }
        defaults.set(data, forKey: Self.key)
        return true
    }
}

enum PetWidgetStatus: Equatable {
    case criticalHunger
    case criticalHappiness
    case criticalEnergy
    case hungry
    case tired
    case normal

    var title: String {
        switch self {
        case .criticalHunger: "Very hungry"
        case .criticalHappiness: "Needs love"
        case .criticalEnergy: "Exhausted"
        case .hungry: "Hungry"
        case .tired: "Tired"
        case .normal: "Doing great"
        }
    }

    var symbolName: String {
        switch self {
        case .criticalHunger, .hungry: "fork.knife"
        case .criticalHappiness: "heart.slash.fill"
        case .criticalEnergy, .tired: "moon.zzz.fill"
        case .normal: "heart.fill"
        }
    }

    static func mostImportant(for snapshot: WidgetPetSnapshot) -> Self {
        if snapshot.hunger >= 90 { return .criticalHunger }
        if snapshot.happiness <= 15 { return .criticalHappiness }
        if snapshot.energy <= 15 { return .criticalEnergy }
        if snapshot.hunger >= 70 { return .hungry }
        if snapshot.energy <= 30 { return .tired }
        return .normal
    }
}

private extension WidgetPetSnapshot {
    func isNewer(than other: WidgetPetSnapshot) -> Bool {
        if version != other.version {
            return version > other.version
        }
        return timestamp > other.timestamp
    }
}
