import Foundation

protocol PetSnapshotCaching {
    func load() -> PetSnapshot?
    func save(_ snapshot: PetSnapshot)
}

struct UserDefaultsPetSnapshotCache: PetSnapshotCaching {
    private static let key = "pocketPet.latestWatchSnapshot"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> PetSnapshot? {
        guard
            let data = defaults.data(forKey: Self.key),
            let snapshot = try? PropertyListDecoder().decode(PetSnapshot.self, from: data),
            snapshot.isValid
        else { return nil }
        return snapshot
    }

    func save(_ snapshot: PetSnapshot) {
        guard let data = try? PropertyListEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
