import Foundation

protocol ProcessedCommandIDPersisting {
    func load() -> [UUID]
    func save(_ ids: [UUID])
}

struct UserDefaultsProcessedCommandIDPersistence: ProcessedCommandIDPersisting {
    private static let key = "pocketPet.processedCommandIDs"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [UUID] {
        defaults.stringArray(forKey: Self.key)?.compactMap(UUID.init(uuidString:))
            ?? []
    }

    func save(_ ids: [UUID]) {
        defaults.set(ids.map(\.uuidString), forKey: Self.key)
    }
}

@MainActor
final class ProcessedCommandIDs {
    static let limit = 50

    private(set) var recentIDs: [UUID]
    private let persistence: any ProcessedCommandIDPersisting

    convenience init() {
        self.init(persistence: UserDefaultsProcessedCommandIDPersistence())
    }

    init(persistence: any ProcessedCommandIDPersisting) {
        self.persistence = persistence
        recentIDs = Array(persistence.load().suffix(Self.limit))
    }

    func contains(_ id: UUID) -> Bool {
        recentIDs.contains(id)
    }

    func record(_ id: UUID) {
        guard !contains(id) else { return }
        recentIDs = Array((recentIDs + [id]).suffix(Self.limit))
        persistence.save(recentIDs)
    }
}
