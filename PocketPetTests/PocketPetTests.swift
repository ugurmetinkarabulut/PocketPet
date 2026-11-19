import Foundation
import Testing
@testable import PocketPet

@MainActor
struct PocketPetTests {
    @Test func renameCommandRoundTrips() throws {
        let command = PetCommand.renamePet(
            name: "Luna",
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            timestamp: Date(timeIntervalSince1970: 123_456)
        )

        let message = try PetCommandCodec.message(for: command)
        let decoded = try PetCommandCodec.command(from: message)

        #expect(decoded == command)
    }

    @Test func legacyCommandWithoutPetNameStillDecodes() throws {
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let legacy = LegacyPetCommand(
            id: id,
            type: PetCommand.playType,
            timestamp: Date(timeIntervalSince1970: 123_456),
            foodID: nil
        )
        let message: [String: Any] = [
            PetCommandCodec.commandIDKey: id.uuidString,
            PetCommandCodec.commandKey: try PropertyListEncoder().encode(legacy),
        ]

        let decoded = try PetCommandCodec.command(from: message)

        #expect(decoded.id == id)
        #expect(decoded.type == PetCommand.playType)
        #expect(decoded.petName == nil)
    }

    @Test func commandApplicationMessageRoundTrips() throws {
        let command = PetCommand.feed(
            foodID: "fish",
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            timestamp: Date(timeIntervalSince1970: 123_456)
        )

        let message = try PetCommandCodec.message(for: command)
        let decoded = try PetCommandCodec.command(from: message)

        #expect(decoded == command)
    }

    @Test func snapshotApplicationContextRoundTrips() throws {
        let snapshot = makeSnapshot(version: 42)

        let context = try PetSnapshotCodec.applicationContext(for: snapshot)
        let decoded = try PetSnapshotCodec.snapshot(from: context)

        #expect(decoded == snapshot)
    }

    @Test func staleSnapshotIsRejected() {
        let cache = MemorySnapshotCache()
        let history = MemorySnapshotHistory()
        let store = PhonePetStore(
            cache: cache,
            historyPersistence: history
        )
        let newest = makeSnapshot(version: 20)
        let stale = makeSnapshot(version: 19)

        #expect(store.accept(newest))
        #expect(store.accept(stale) == false)
        #expect(store.snapshot == newest)
        #expect(cache.snapshot == newest)
    }

    @Test func acceptedSnapshotPersistsAndReloadsWidget() {
        let widgetStore = MemoryWidgetSnapshotStore()
        let reloader = MemoryWidgetReloader()
        let store = PhonePetStore(
            cache: MemorySnapshotCache(),
            historyPersistence: MemorySnapshotHistory(),
            widgetPersistence: widgetStore,
            widgetReloader: reloader
        )
        let snapshot = makeSnapshot(version: 4)

        #expect(store.accept(snapshot))
        #expect(widgetStore.snapshot == WidgetPetSnapshot(snapshot: snapshot))
        #expect(reloader.reloadCount == 1)
    }

    @Test func staleSnapshotDoesNotUpdateOrReloadWidget() {
        let newest = makeSnapshot(version: 20)
        let widgetStore = MemoryWidgetSnapshotStore(
            snapshot: WidgetPetSnapshot(snapshot: newest)
        )
        let reloader = MemoryWidgetReloader()
        let store = PhonePetStore(
            cache: MemorySnapshotCache(snapshot: newest),
            historyPersistence: MemorySnapshotHistory(),
            widgetPersistence: widgetStore,
            widgetReloader: reloader
        )

        #expect(store.accept(makeSnapshot(version: 19)) == false)
        #expect(widgetStore.snapshot == WidgetPetSnapshot(snapshot: newest))
        #expect(reloader.reloadCount == 0)
    }

    @Test func newerSnapshotReplacesOlderWidgetSnapshot() {
        let old = makeSnapshot(version: 3)
        let newer = makeSnapshot(version: 4)
        let widgetStore = MemoryWidgetSnapshotStore(
            snapshot: WidgetPetSnapshot(snapshot: old)
        )
        let store = PhonePetStore(
            cache: MemorySnapshotCache(snapshot: old),
            historyPersistence: MemorySnapshotHistory(),
            widgetPersistence: widgetStore,
            widgetReloader: MemoryWidgetReloader()
        )

        #expect(store.accept(newer))
        #expect(widgetStore.snapshot == WidgetPetSnapshot(snapshot: newer))
    }

    @Test func cachedSnapshotMigratesToEmptyWidgetStoreWithoutDeletion() {
        let cached = makeSnapshot(version: 7)
        let cache = MemorySnapshotCache(snapshot: cached)
        let widgetStore = MemoryWidgetSnapshotStore()
        let reloader = MemoryWidgetReloader()

        _ = PhonePetStore(
            cache: cache,
            historyPersistence: MemorySnapshotHistory(),
            widgetPersistence: widgetStore,
            widgetReloader: reloader
        )

        #expect(cache.snapshot == cached)
        #expect(widgetStore.snapshot == WidgetPetSnapshot(snapshot: cached))
        #expect(reloader.reloadCount == 1)
    }

    @Test func migrationDoesNotReplaceNewerWidgetSnapshot() {
        let cached = makeSnapshot(version: 7)
        let shared = makeSnapshot(version: 8)
        let widgetStore = MemoryWidgetSnapshotStore(
            snapshot: WidgetPetSnapshot(snapshot: shared)
        )

        _ = PhonePetStore(
            cache: MemorySnapshotCache(snapshot: cached),
            historyPersistence: MemorySnapshotHistory(),
            widgetPersistence: widgetStore,
            widgetReloader: MemoryWidgetReloader()
        )

        #expect(widgetStore.snapshot == WidgetPetSnapshot(snapshot: shared))
    }

    @Test func widgetSnapshotPersistenceRestoresAndRejectsStaleData() throws {
        let suiteName = "PocketPetWidgetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = UserDefaultsWidgetSnapshotStore(defaults: defaults)
        let current = WidgetPetSnapshot(snapshot: makeSnapshot(version: 10))
        let stale = WidgetPetSnapshot(snapshot: makeSnapshot(version: 9))

        #expect(persistence.load() == nil)
        #expect(persistence.saveIfNewer(current))
        #expect(persistence.saveIfNewer(stale) == false)
        #expect(persistence.load() == current)
    }

    @Test func widgetStatusUsesDeterministicPriority() {
        let base = makeSnapshot(version: 1)

        #expect(
            PetWidgetStatus.mostImportant(
                for: WidgetPetSnapshot(
                    snapshot: makeSnapshot(
                        version: 2,
                        hunger: 95,
                        happiness: 5,
                        energy: 5
                    )
                )
            ) == .criticalHunger
        )
        #expect(
            PetWidgetStatus.mostImportant(
                for: WidgetPetSnapshot(
                    snapshot: makeSnapshot(
                        version: 3,
                        hunger: 20,
                        happiness: 10,
                        energy: 5
                    )
                )
            ) == .criticalHappiness
        )
        #expect(
            PetWidgetStatus.mostImportant(
                for: WidgetPetSnapshot(
                    snapshot: makeSnapshot(
                        version: 4,
                        hunger: 20,
                        happiness: 80,
                        energy: 10
                    )
                )
            ) == .criticalEnergy
        )
        #expect(
            PetWidgetStatus.mostImportant(
                for: WidgetPetSnapshot(snapshot: base)
            ) == .normal
        )
    }

    @Test func cachedSnapshotRestoresAsSavedData() throws {
        let cached = makeSnapshot(version: 7)
        let suiteName = "PocketPetSnapshotTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        UserDefaultsPetSnapshotCache(defaults: defaults).save(cached)

        let restored = PhonePetStore(
            cache: UserDefaultsPetSnapshotCache(defaults: defaults),
            historyPersistence: UserDefaultsPetSnapshotHistory(defaults: defaults)
        )

        #expect(restored.snapshot == cached)
        #expect(restored.isShowingCachedSnapshot)
    }

    @Test func historyDeduplicatesUnchangedSnapshots() {
        let history = MemorySnapshotHistory()
        let store = PhonePetStore(
            cache: MemorySnapshotCache(),
            historyPersistence: history
        )

        #expect(store.accept(makeSnapshot(version: 1)))
        #expect(store.accept(makeSnapshot(version: 2)))

        #expect(store.history.count == 1)
        #expect(history.snapshots.count == 1)
        #expect(store.snapshot?.version == 2)
    }

    @Test func historyIsCappedAtTimelineLimit() {
        let store = PhonePetStore(
            cache: MemorySnapshotCache(),
            historyPersistence: MemorySnapshotHistory()
        )

        for version in 1...Int64(PetSnapshotTimeline.limit + 5) {
            #expect(
                store.accept(
                    makeSnapshot(version: version, xp: Int(version))
                )
            )
        }

        #expect(store.history.count == PetSnapshotTimeline.limit)
        #expect(store.history.first?.version == 6)
        #expect(store.history.last?.version == Int64(PetSnapshotTimeline.limit + 5))
    }

    @Test func historyPersistsAndRestores() throws {
        let suiteName = "PocketPetHistoryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = makeSnapshot(version: 1, xp: 100)
        let latest = makeSnapshot(version: 2, xp: 140)
        let cache = UserDefaultsPetSnapshotCache(defaults: defaults)
        let history = UserDefaultsPetSnapshotHistory(defaults: defaults)
        cache.save(latest)
        history.save([first, latest])

        let restored = PhonePetStore(
            cache: cache,
            historyPersistence: history
        )

        #expect(restored.history == [first, latest])
        #expect(restored.snapshot == latest)
    }

    @Test func meaningfulActivityIsDerivedFromSafeDifferences() {
        let earlier = Date(timeIntervalSince1970: 100_000)
        let previous = makeSnapshot(
            version: 1,
            timestamp: earlier,
            hunger: 50,
            happiness: 80,
            energy: 80,
            xp: 90,
            level: 1,
            steps: 2_500
        )
        let current = makeSnapshot(
            version: 2,
            timestamp: earlier.addingTimeInterval(60),
            hunger: 75,
            happiness: 60,
            energy: 60,
            xp: 230,
            level: 3,
            steps: 4_100
        )

        let kinds = PetActivityDeriver.activities(from: [previous, current])
            .map(\.kind)

        #expect(kinds.contains(.levelIncreased(to: 3)))
        #expect(kinds.contains(.xpIncreased(by: 140)))
        #expect(kinds.contains(.becameHungry))
        #expect(kinds.contains(.happinessChanged(by: -20)))
        #expect(kinds.contains(.energyChanged(by: -20)))
        #expect(kinds.contains(.stepMilestone(4_000)))
    }

    @Test func staleSnapshotsNeverEnterHistory() {
        let history = MemorySnapshotHistory()
        let store = PhonePetStore(
            cache: MemorySnapshotCache(),
            historyPersistence: history
        )

        #expect(store.accept(makeSnapshot(version: 20, xp: 200)))
        #expect(store.accept(makeSnapshot(version: 19, xp: 190)) == false)

        #expect(store.history.map(\.version) == [20])
        #expect(history.snapshots.map(\.version) == [20])
    }

    @Test func staleCommandResponseCannotReplaceNewerSnapshot() {
        let store = PhonePetStore(
            cache: MemorySnapshotCache(),
            historyPersistence: MemorySnapshotHistory()
        )
        let newest = makeSnapshot(version: 20, xp: 200)
        let stale = makeSnapshot(version: 19, xp: 190)
        #expect(store.accept(newest))
        let controller = PhoneConnectivityController(store: store, session: nil)
        let commandID = UUID()
        let acknowledgement = PetCommandAcknowledgement.succeeded(
            commandID: commandID,
            snapshot: stale
        )

        let accepted = controller.applySuccessfulSnapshot(
            from: acknowledgement,
            expectedCommandID: commandID
        )

        #expect(accepted == false)
        #expect(store.snapshot == newest)
        #expect(store.history.map(\.version) == [20])
    }

    @Test func staleRenameAcknowledgementCannotReplaceNewerSnapshot() {
        let store = PhonePetStore(
            cache: MemorySnapshotCache(),
            historyPersistence: MemorySnapshotHistory()
        )
        let newest = makeSnapshot(version: 20, xp: 200)
        let staleRename = PetSnapshot(
            version: 19,
            timestamp: Date(timeIntervalSince1970: 100_019),
            petName: "Luna",
            hunger: 25,
            happiness: 80,
            energy: 70,
            xp: 190,
            level: 2,
            visualState: "happy",
            todayStepCount: 3_500
        )
        #expect(store.accept(newest))
        let controller = PhoneConnectivityController(store: store, session: nil)
        let commandID = UUID()
        let acknowledgement = PetCommandAcknowledgement.succeeded(
            commandID: commandID,
            snapshot: staleRename
        )

        let accepted = controller.applySuccessfulSnapshot(
            from: acknowledgement,
            expectedCommandID: commandID
        )

        #expect(accepted == false)
        #expect(store.snapshot == newest)
        #expect(store.history.map(\.version) == [20])
    }

    @Test func appVersionInfoFormatsBundleMetadata() {
        let info = AppVersionInfo(
            infoDictionary: [
                "CFBundleDisplayName": "PocketPet",
                "CFBundleShortVersionString": "2.3",
                "CFBundleVersion": "45",
            ]
        )

        #expect(info.appName == "PocketPet")
        #expect(info.version == "2.3")
        #expect(info.build == "45")
    }

    @Test func failedAndUnreachableCommandsDoNotMutateIPhoneState() {
        let store = PhonePetStore(
            cache: MemorySnapshotCache(),
            historyPersistence: MemorySnapshotHistory()
        )
        let snapshot = makeSnapshot(version: 10)
        #expect(store.accept(snapshot))
        let controller = PhoneConnectivityController(store: store, session: nil)
        let commandID = UUID()
        let failure = PetCommandAcknowledgement.failed(
            commandID: commandID,
            reason: .invalidFoodID
        )

        #expect(
            controller.applySuccessfulSnapshot(
                from: failure,
                expectedCommandID: commandID
            ) == false
        )
        #expect(store.snapshot == snapshot)

        controller.sendPlay()

        #expect(store.snapshot == snapshot)
        #expect(store.history == [snapshot])
        guard case .failed(_, .watchUnavailable) = controller.commandState else {
            Issue.record("Expected an immediate unreachable-Watch failure")
            return
        }
    }

    private func makeSnapshot(
        version: Int64,
        timestamp: Date? = nil,
        hunger: Double = 25,
        happiness: Double = 80,
        energy: Double = 70,
        xp: Int = 140,
        level: Int = 2,
        steps: Int? = 3_500
    ) -> PetSnapshot {
        PetSnapshot(
            version: version,
            timestamp: timestamp
                ?? Date(timeIntervalSince1970: 100_000 + TimeInterval(version)),
            petName: "Mochi",
            hunger: hunger,
            happiness: happiness,
            energy: energy,
            xp: xp,
            level: level,
            visualState: "happy",
            todayStepCount: steps
        )
    }
}

private struct LegacyPetCommand: Codable {
    let id: UUID
    let type: String
    let timestamp: Date
    let foodID: String?
}

private final class MemorySnapshotCache: PetSnapshotCaching {
    var snapshot: PetSnapshot?

    init(snapshot: PetSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func load() -> PetSnapshot? { snapshot }
    func save(_ snapshot: PetSnapshot) { self.snapshot = snapshot }
}

private final class MemorySnapshotHistory: PetSnapshotHistoryPersisting {
    var snapshots: [PetSnapshot]

    init(snapshots: [PetSnapshot] = []) {
        self.snapshots = snapshots
    }

    func load() -> [PetSnapshot] { snapshots }
    func save(_ snapshots: [PetSnapshot]) { self.snapshots = snapshots }
}

private final class MemoryWidgetSnapshotStore: WidgetSnapshotPersisting {
    var snapshot: WidgetPetSnapshot?

    init(snapshot: WidgetPetSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func load() -> WidgetPetSnapshot? { snapshot }

    func saveIfNewer(_ candidate: WidgetPetSnapshot) -> Bool {
        if let snapshot {
            if candidate.version < snapshot.version {
                return false
            }
            if candidate.version == snapshot.version,
               candidate.timestamp <= snapshot.timestamp {
                return false
            }
        }
        snapshot = candidate
        return true
    }
}

private final class MemoryWidgetReloader: WidgetTimelineReloading {
    var reloadCount = 0

    func reloadPocketPetWidget() {
        reloadCount += 1
    }
}
