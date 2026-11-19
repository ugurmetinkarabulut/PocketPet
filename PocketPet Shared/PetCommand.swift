import Foundation

struct PetCommand: Codable, Equatable, Sendable {
    static let playType = "play"
    static let petType = "pet"
    static let feedType = "feed"
    static let renamePetType = "renamePet"
    static let requestSnapshotType = "requestSnapshot"

    let id: UUID
    let type: String
    let timestamp: Date
    let foodID: String?
    let petName: String?

    init(
        id: UUID,
        type: String,
        timestamp: Date,
        foodID: String?,
        petName: String? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.foodID = foodID
        self.petName = petName
    }

    static func play(id: UUID = UUID(), timestamp: Date = .now) -> PetCommand {
        PetCommand(id: id, type: playType, timestamp: timestamp, foodID: nil)
    }

    static func pet(id: UUID = UUID(), timestamp: Date = .now) -> PetCommand {
        PetCommand(id: id, type: petType, timestamp: timestamp, foodID: nil)
    }

    static func feed(
        foodID: String,
        id: UUID = UUID(),
        timestamp: Date = .now
    ) -> PetCommand {
        PetCommand(id: id, type: feedType, timestamp: timestamp, foodID: foodID)
    }

    static func renamePet(
        name: String,
        id: UUID = UUID(),
        timestamp: Date = .now
    ) -> PetCommand {
        PetCommand(
            id: id,
            type: renamePetType,
            timestamp: timestamp,
            foodID: nil,
            petName: name
        )
    }

    static func requestSnapshot(
        id: UUID = UUID(),
        timestamp: Date = .now
    ) -> PetCommand {
        PetCommand(
            id: id,
            type: requestSnapshotType,
            timestamp: timestamp,
            foodID: nil
        )
    }
}

enum PetNameRules {
    static let characterLimit = 16

    static func validatedName(_ candidate: String) -> String? {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= characterLimit else {
            return nil
        }
        return trimmed
    }

    static func limitedName(_ candidate: String) -> String {
        String(candidate.prefix(characterLimit))
    }
}

enum PetCommandErrorReason: String, Codable, Equatable, Error, Sendable {
    case malformedCommand
    case unsupportedAction
    case invalidFoodID
    case invalidPetName
    case duplicateCommand
    case expiredCommand
    case watchUnavailable
    case invalidResponse
    case transportFailure
}

struct PetCommandAcknowledgement: Codable, Equatable, Sendable {
    let commandID: UUID
    let success: Bool
    let snapshot: PetSnapshot?
    let errorReason: PetCommandErrorReason?

    static func succeeded(
        commandID: UUID,
        snapshot: PetSnapshot
    ) -> PetCommandAcknowledgement {
        PetCommandAcknowledgement(
            commandID: commandID,
            success: true,
            snapshot: snapshot,
            errorReason: nil
        )
    }

    static func failed(
        commandID: UUID,
        reason: PetCommandErrorReason
    ) -> PetCommandAcknowledgement {
        PetCommandAcknowledgement(
            commandID: commandID,
            success: false,
            snapshot: nil,
            errorReason: reason
        )
    }

    var isValid: Bool {
        if success {
            return errorReason == nil && snapshot?.isValid == true
        }
        return snapshot == nil && errorReason != nil
    }
}

enum PetCommandCodec {
    static let commandKey = "petCommand"
    static let commandIDKey = "petCommandID"
    static let acknowledgementKey = "petCommandAcknowledgement"

    static func message(for command: PetCommand) throws -> [String: Any] {
        [
            commandIDKey: command.id.uuidString,
            commandKey: try PropertyListEncoder().encode(command),
        ]
    }

    static func command(from message: [String: Any]) throws -> PetCommand {
        guard
            let idString = message[commandIDKey] as? String,
            let envelopeID = UUID(uuidString: idString),
            let data = message[commandKey] as? Data
        else { throw PetCommandCodingError.malformedCommand }

        let command = try PropertyListDecoder().decode(PetCommand.self, from: data)
        guard command.id == envelopeID else {
            throw PetCommandCodingError.mismatchedCommandID
        }
        return command
    }

    static func commandID(from message: [String: Any]) -> UUID? {
        guard let idString = message[commandIDKey] as? String else { return nil }
        return UUID(uuidString: idString)
    }

    static func message(
        for acknowledgement: PetCommandAcknowledgement
    ) throws -> [String: Any] {
        [
            acknowledgementKey: try PropertyListEncoder().encode(
                acknowledgement
            ),
        ]
    }

    static func acknowledgement(
        from message: [String: Any]
    ) throws -> PetCommandAcknowledgement {
        guard let data = message[acknowledgementKey] as? Data else {
            throw PetCommandCodingError.malformedAcknowledgement
        }
        let acknowledgement = try PropertyListDecoder().decode(
            PetCommandAcknowledgement.self,
            from: data
        )
        guard acknowledgement.isValid else {
            throw PetCommandCodingError.malformedAcknowledgement
        }
        return acknowledgement
    }
}

enum PetCommandCodingError: Error {
    case malformedCommand
    case mismatchedCommandID
    case malformedAcknowledgement
}
