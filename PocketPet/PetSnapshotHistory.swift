import Foundation

protocol PetSnapshotHistoryPersisting {
    func load() -> [PetSnapshot]
    func save(_ snapshots: [PetSnapshot])
}

struct UserDefaultsPetSnapshotHistory: PetSnapshotHistoryPersisting {
    private static let key = "pocketPet.snapshotHistory"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [PetSnapshot] {
        guard
            let data = defaults.data(forKey: Self.key),
            let snapshots = try? PropertyListDecoder().decode(
                [PetSnapshot].self,
                from: data
            )
        else { return [] }
        return snapshots
    }

    func save(_ snapshots: [PetSnapshot]) {
        guard let data = try? PropertyListEncoder().encode(snapshots) else {
            return
        }
        defaults.set(data, forKey: Self.key)
    }
}

enum PetSnapshotTimeline {
    static let limit = 40

    static func normalized(_ snapshots: [PetSnapshot]) -> [PetSnapshot] {
        var result: [PetSnapshot] = []
        for snapshot in snapshots
            .filter(\.isValid)
            .sorted(by: { $0.version < $1.version }) {
            result = appending(snapshot, to: result)
        }
        return result
    }

    static func appending(
        _ snapshot: PetSnapshot,
        to snapshots: [PetSnapshot]
    ) -> [PetSnapshot] {
        guard snapshots.last?.hasSameRecordedState(as: snapshot) != true else {
            return snapshots
        }
        return Array((snapshots + [snapshot]).suffix(limit))
    }
}

private extension PetSnapshot {
    func hasSameRecordedState(as other: PetSnapshot) -> Bool {
        petName == other.petName
            && hunger == other.hunger
            && happiness == other.happiness
            && energy == other.energy
            && xp == other.xp
            && level == other.level
            && visualState == other.visualState
            && todayStepCount == other.todayStepCount
    }
}
