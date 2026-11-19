import Foundation
import Observation
import WatchConnectivity

enum PhoneCommandState: Equatable {
    case idle
    case sending(PetCommand)
    case succeeded(PetCommand)
    case failed(PetCommand?, PetCommandErrorReason)
}

enum PhoneSessionActivationState: Equatable {
    case unsupported
    case notActivated
    case activating
    case inactive
    case activated
    case failed
}

@MainActor
@Observable
final class PhoneConnectivityController: NSObject {
    private(set) var commandState: PhoneCommandState = .idle
    private(set) var isWatchReachable = false
    private(set) var isWatchPaired = false
    private(set) var isWatchAppInstalled = false
    private(set) var activationState: PhoneSessionActivationState = .notActivated
    private(set) var lastSuccessfulSynchronization: Date?

    private let store: PhonePetStore
    private let session: WCSession?
    private var inFlightCommandID: UUID?

    convenience init(store: PhonePetStore) {
        self.init(
            store: store,
            session: WCSession.isSupported() ? .default : nil
        )
    }

    init(store: PhonePetStore, session: WCSession?) {
        self.store = store
        self.session = session
        super.init()
    }

    var canSendGameplayCommand: Bool {
        canSendCommand
    }

    var canSendCommand: Bool {
        isWatchReachable && inFlightCommandID == nil
    }

    func activate() {
        guard let session else {
            isWatchReachable = false
            activationState = .unsupported
            store.updateConnectionState(.unsupported)
            return
        }
        activationState = .activating
        store.updateConnectionState(.activating)
        session.delegate = self
        session.activate()
    }

    func sendPlay() {
        send(.play())
    }

    func sendPet() {
        send(.pet())
    }

    func sendFeed(foodID: String) {
        send(.feed(foodID: foodID))
    }

    func sendRenamePet(name: String) {
        send(.renamePet(name: name))
    }

    func syncNow() {
        send(.requestSnapshot())
    }

    func send(_ command: PetCommand) {
        guard inFlightCommandID == nil else { return }
        guard
            let session,
            session.activationState == .activated,
            session.isReachable
        else {
            commandState = .failed(command, .watchUnavailable)
            return
        }

        let message: [String: Any]
        do {
            message = try PetCommandCodec.message(for: command)
        } catch {
            commandState = .failed(command, .malformedCommand)
            return
        }

        inFlightCommandID = command.id
        commandState = .sending(command)
        session.sendMessage(
            message,
            replyHandler: { [weak self] message in
                Task { @MainActor in
                    guard let self else { return }
                    guard let acknowledgement = try? PetCommandCodec
                        .acknowledgement(from: message) else {
                        self.finish(command, failure: .invalidResponse)
                        return
                    }
                    self.finish(command, acknowledgement: acknowledgement)
                }
            },
            errorHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.finish(command, failure: .transportFailure)
                }
            }
        )
    }

    @discardableResult
    func applySuccessfulSnapshot(
        from acknowledgement: PetCommandAcknowledgement,
        expectedCommandID: UUID
    ) -> Bool {
        guard acknowledgement.commandID == expectedCommandID,
              acknowledgement.success,
              let snapshot = acknowledgement.snapshot,
              snapshot.isValid else { return false }
        return store.accept(snapshot)
    }

    private func finish(
        _ command: PetCommand,
        acknowledgement: PetCommandAcknowledgement
    ) {
        guard inFlightCommandID == command.id else { return }
        inFlightCommandID = nil

        guard acknowledgement.commandID == command.id else {
            commandState = .failed(command, .invalidResponse)
            return
        }

        if acknowledgement.success {
            lastSuccessfulSynchronization = .now
            _ = applySuccessfulSnapshot(
                from: acknowledgement,
                expectedCommandID: command.id
            )
            commandState = .succeeded(command)
        } else {
            commandState = .failed(
                command,
                acknowledgement.errorReason ?? .invalidResponse
            )
        }
    }

    private func finish(
        _ command: PetCommand,
        failure: PetCommandErrorReason
    ) {
        guard inFlightCommandID == command.id else { return }
        inFlightCommandID = nil
        commandState = .failed(command, failure)
    }

    private func updateState(for session: WCSession) {
        isWatchPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled

        guard session.activationState == .activated else {
            isWatchReachable = false
            switch session.activationState {
            case .notActivated:
                activationState = .activating
            case .inactive:
                activationState = .inactive
            case .activated:
                activationState = .activated
            @unknown default:
                activationState = .failed
            }
            store.updateConnectionState(.activating)
            return
        }
        activationState = .activated
        guard session.isPaired else {
            isWatchReachable = false
            store.updateConnectionState(.noPairedWatch)
            return
        }
        guard session.isWatchAppInstalled else {
            isWatchReachable = false
            store.updateConnectionState(.watchAppNotInstalled)
            return
        }
        isWatchReachable = session.isReachable
        store.updateConnectionState(.ready(isReachable: session.isReachable))
    }

    private func receive(_ context: [String: Any]) {
        guard let snapshot = try? PetSnapshotCodec.snapshot(from: context) else {
            return
        }
        lastSuccessfulSynchronization = .now
        _ = store.accept(snapshot)
    }
}

extension PhoneConnectivityController: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let error {
                isWatchReachable = false
                self.activationState = .failed
                store.updateConnectionState(.unavailable(error.localizedDescription))
                return
            }
            updateState(for: session)
            if !session.receivedApplicationContext.isEmpty {
                receive(session.receivedApplicationContext)
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor [weak self] in
            self?.receive(applicationContext)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.updateState(for: session)
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            self?.updateState(for: session)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
