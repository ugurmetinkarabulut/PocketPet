import Foundation
import WatchConnectivity

protocol PetSnapshotSending: AnyObject {
    @discardableResult
    func send(_ snapshot: PetSnapshot) -> PetSnapshot
}

final class WatchConnectivityController: NSObject, PetSnapshotSending {
    private let session: WCSession?
    private var latestSnapshot: PetSnapshot?
    private var commandHandler: PetCommandHandler?

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func connectCommandHandler(to store: PetStateStore) {
        commandHandler = PetCommandHandler(store: store)
    }

    @discardableResult
    func send(_ snapshot: PetSnapshot) -> PetSnapshot {
        let normalized = normalized(snapshot)
        latestSnapshot = normalized
        sendLatestSnapshot()
        return normalized
    }

    private func normalized(_ snapshot: PetSnapshot) -> PetSnapshot {
        guard let latestSnapshot, snapshot.version <= latestSnapshot.version else {
            return snapshot
        }
        return PetSnapshot(
            version: latestSnapshot.version + 1,
            timestamp: snapshot.timestamp,
            petName: snapshot.petName,
            hunger: snapshot.hunger,
            happiness: snapshot.happiness,
            energy: snapshot.energy,
            xp: snapshot.xp,
            level: snapshot.level,
            visualState: snapshot.visualState,
            todayStepCount: snapshot.todayStepCount
        )
    }

    private func sendLatestSnapshot() {
        guard
            let session,
            session.activationState == .activated,
            let latestSnapshot,
            let context = try? PetSnapshotCodec.applicationContext(for: latestSnapshot)
        else { return }

        try? session.updateApplicationContext(context)
    }
}

extension WatchConnectivityController: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, error == nil else { return }
        sendLatestSnapshot()
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        guard let commandID = PetCommandCodec.commandID(from: message) else {
            replyHandler([:])
            return
        }

        guard let command = try? PetCommandCodec.command(from: message) else {
            let acknowledgement = PetCommandAcknowledgement.failed(
                commandID: commandID,
                reason: .malformedCommand
            )
            replyHandler(
                (try? PetCommandCodec.message(for: acknowledgement)) ?? [:]
            )
            return
        }

        guard let commandHandler else {
            let acknowledgement = PetCommandAcknowledgement.failed(
                commandID: command.id,
                reason: .watchUnavailable
            )
            replyHandler(
                (try? PetCommandCodec.message(for: acknowledgement)) ?? [:]
            )
            return
        }

        let acknowledgement = commandHandler.handle(command)
        replyHandler((try? PetCommandCodec.message(for: acknowledgement)) ?? [:])
    }
}
