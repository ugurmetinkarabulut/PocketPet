import Foundation

@MainActor
final class PetCommandHandler {
    private enum ValidatedAction {
        case play
        case pet
        case feed(Food)
        case renamePet(String)
        case requestSnapshot
    }

    private static let maximumCommandAge: TimeInterval = 5 * 60
    private static let maximumFutureSkew: TimeInterval = 60

    private let store: PetStateStore
    private let processedIDs: ProcessedCommandIDs
    private let now: () -> Date

    convenience init(store: PetStateStore) {
        self.init(
            store: store,
            processedIDs: ProcessedCommandIDs(),
            now: Date.init
        )
    }

    init(
        store: PetStateStore,
        processedIDs: ProcessedCommandIDs,
        now: @escaping () -> Date
    ) {
        self.store = store
        self.processedIDs = processedIDs
        self.now = now
    }

    func handle(_ command: PetCommand) -> PetCommandAcknowledgement {
        let currentDate = now()
        let age = currentDate.timeIntervalSince(command.timestamp)
        guard age.isFinite,
              age <= Self.maximumCommandAge,
              age >= -Self.maximumFutureSkew else {
            return .failed(commandID: command.id, reason: .expiredCommand)
        }

        let action: ValidatedAction
        switch validate(command) {
        case .success(let validatedAction):
            action = validatedAction
        case .failure(let reason):
            return .failed(commandID: command.id, reason: reason)
        }

        guard !processedIDs.contains(command.id) else {
            return .failed(commandID: command.id, reason: .duplicateCommand)
        }

        // Persist before mutation so a retried command can never execute twice.
        processedIDs.record(command.id)

        let snapshot: PetSnapshot
        switch action {
        case .play:
            snapshot = store.play(at: currentDate)
        case .pet:
            snapshot = store.pet(at: currentDate)
        case .feed(let food):
            snapshot = store.feed(food, at: currentDate)
        case .renamePet(let name):
            guard let renamedSnapshot = store.renamePet(name, at: currentDate) else {
                return .failed(commandID: command.id, reason: .invalidPetName)
            }
            snapshot = renamedSnapshot
        case .requestSnapshot:
            snapshot = store.sendLatestSnapshot(at: currentDate)
        }

        return .succeeded(commandID: command.id, snapshot: snapshot)
    }

    private func validate(
        _ command: PetCommand
    ) -> Result<ValidatedAction, PetCommandErrorReason> {
        switch command.type {
        case PetCommand.playType:
            guard command.foodID == nil, command.petName == nil else {
                return .failure(.malformedCommand)
            }
            return .success(.play)

        case PetCommand.petType:
            guard command.foodID == nil, command.petName == nil else {
                return .failure(.malformedCommand)
            }
            return .success(.pet)

        case PetCommand.feedType:
            guard command.petName == nil else {
                return .failure(.malformedCommand)
            }
            guard let foodID = command.foodID, !foodID.isEmpty else {
                return .failure(.malformedCommand)
            }
            guard let food = Food.food(withID: foodID) else {
                return .failure(.invalidFoodID)
            }
            return .success(.feed(food))

        case PetCommand.renamePetType:
            guard command.foodID == nil, let petName = command.petName else {
                return .failure(.malformedCommand)
            }
            guard let validatedName = PetNameRules.validatedName(petName) else {
                return .failure(.invalidPetName)
            }
            return .success(.renamePet(validatedName))

        case PetCommand.requestSnapshotType:
            guard command.foodID == nil, command.petName == nil else {
                return .failure(.malformedCommand)
            }
            return .success(.requestSnapshot)

        default:
            return .failure(.unsupportedAction)
        }
    }
}
