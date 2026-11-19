import Foundation
import Observation

enum WatchConnectionState: Equatable {
    case activating
    case ready(isReachable: Bool)
    case unsupported
    case noPairedWatch
    case watchAppNotInstalled
    case unavailable(String)
}

@MainActor
@Observable
final class PhonePetStore {
    private(set) var snapshot: PetSnapshot?
    private(set) var history: [PetSnapshot]
    private(set) var connectionState: WatchConnectionState = .activating
    private(set) var isShowingCachedSnapshot: Bool

    private let cache: any PetSnapshotCaching
    private let historyPersistence: any PetSnapshotHistoryPersisting
    private let widgetPersistence: (any WidgetSnapshotPersisting)?
    private let widgetReloader: (any WidgetTimelineReloading)?

    convenience init() {
        self.init(
            cache: UserDefaultsPetSnapshotCache(),
            historyPersistence: UserDefaultsPetSnapshotHistory(),
            widgetPersistence: UserDefaultsWidgetSnapshotStore.appGroupStore(),
            widgetReloader: WidgetCenterTimelineReloader()
        )
    }

    init(
        cache: any PetSnapshotCaching,
        historyPersistence: any PetSnapshotHistoryPersisting,
        widgetPersistence: (any WidgetSnapshotPersisting)? = nil,
        widgetReloader: (any WidgetTimelineReloading)? = nil
    ) {
        self.cache = cache
        self.historyPersistence = historyPersistence
        self.widgetPersistence = widgetPersistence
        self.widgetReloader = widgetReloader
        let restoredSnapshot = cache.load()
        var restoredHistory = PetSnapshotTimeline.normalized(
            historyPersistence.load()
        )
        if restoredHistory.isEmpty, let restoredSnapshot {
            restoredHistory = [restoredSnapshot]
            historyPersistence.save(restoredHistory)
        }
        snapshot = restoredSnapshot
        history = restoredHistory
        isShowingCachedSnapshot = restoredSnapshot != nil

        if let restoredSnapshot {
            if widgetPersistence?.saveIfNewer(
                WidgetPetSnapshot(snapshot: restoredSnapshot)
            ) == true {
                widgetReloader?.reloadPocketPetWidget()
            }
        }
    }

    @discardableResult
    func accept(_ candidate: PetSnapshot) -> Bool {
        guard candidate.isValid else { return false }
        if let snapshot, !candidate.isNewer(than: snapshot) {
            return false
        }

        snapshot = candidate
        isShowingCachedSnapshot = false
        cache.save(candidate)
        let updatedHistory = PetSnapshotTimeline.appending(candidate, to: history)
        if updatedHistory != history {
            history = updatedHistory
            historyPersistence.save(updatedHistory)
        }
        if widgetPersistence?.saveIfNewer(
            WidgetPetSnapshot(snapshot: candidate)
        ) == true {
            widgetReloader?.reloadPocketPetWidget()
        }
        return true
    }

    func updateConnectionState(_ state: WatchConnectionState) {
        connectionState = state
    }
}
