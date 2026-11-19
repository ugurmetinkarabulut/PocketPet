import Foundation

struct PetSnapshot: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let version: Int64
    let timestamp: Date
    let petName: String
    let hunger: Double
    let happiness: Double
    let energy: Double
    let xp: Int
    let level: Int
    let visualState: String
    let todayStepCount: Int?

    init(
        schemaVersion: Int = PetSnapshot.schemaVersion,
        version: Int64,
        timestamp: Date,
        petName: String,
        hunger: Double,
        happiness: Double,
        energy: Double,
        xp: Int,
        level: Int,
        visualState: String,
        todayStepCount: Int?
    ) {
        self.schemaVersion = schemaVersion
        self.version = version
        self.timestamp = timestamp
        self.petName = petName
        self.hunger = hunger
        self.happiness = happiness
        self.energy = energy
        self.xp = xp
        self.level = level
        self.visualState = visualState
        self.todayStepCount = todayStepCount
    }

    var isValid: Bool {
        schemaVersion == Self.schemaVersion
            && version > 0
            && timestamp.timeIntervalSince1970.isFinite
            && !petName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (0...100).contains(hunger)
            && (0...100).contains(happiness)
            && (0...100).contains(energy)
            && hunger.isFinite
            && happiness.isFinite
            && energy.isFinite
            && xp >= 0
            && level >= 1
            && !visualState.isEmpty
            && todayStepCount.map { $0 >= 0 } != false
    }

    func isNewer(than other: PetSnapshot) -> Bool {
        if version != other.version {
            return version > other.version
        }
        return timestamp > other.timestamp
    }
}

enum PetSnapshotCodec {
    static let contextKey = "petSnapshot"

    static func applicationContext(for snapshot: PetSnapshot) throws -> [String: Any] {
        [contextKey: try PropertyListEncoder().encode(snapshot)]
    }

    static func snapshot(from applicationContext: [String: Any]) throws -> PetSnapshot {
        guard let data = applicationContext[contextKey] as? Data else {
            throw PetSnapshotCodingError.missingSnapshot
        }
        let snapshot = try PropertyListDecoder().decode(PetSnapshot.self, from: data)
        guard snapshot.isValid else {
            throw PetSnapshotCodingError.invalidSnapshot
        }
        return snapshot
    }
}

enum PetSnapshotCodingError: Error {
    case missingSnapshot
    case invalidSnapshot
}
