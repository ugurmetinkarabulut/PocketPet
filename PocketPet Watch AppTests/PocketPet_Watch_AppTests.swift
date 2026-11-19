//
//  PocketPet_Watch_AppTests.swift
//  PocketPet Watch AppTests
//
//  Created by Uğur Metin Karabulut on 20.09.2026.
//

import Foundation
import Testing
@testable import PocketPet_Watch_App

@MainActor
struct PocketPet_Watch_AppTests {
    @Test func validRenameCommandUpdatesPersistedPetName() {
        let context = makeCommandContext()

        let acknowledgement = context.handler.handle(
            .renamePet(name: "Luna", timestamp: context.now)
        )

        #expect(acknowledgement.success)
        #expect(context.store.state.name == "Luna")
        #expect(acknowledgement.snapshot?.petName == "Luna")
    }

    @Test func renameCommandTrimsWhitespace() {
        let context = makeCommandContext()

        let acknowledgement = context.handler.handle(
            .renamePet(name: "  Luna \n", timestamp: context.now)
        )

        #expect(acknowledgement.success)
        #expect(context.store.state.name == "Luna")
        #expect(acknowledgement.snapshot?.petName == "Luna")
    }

    @Test func emptyRenameIsRejectedWithoutMutation() {
        let context = makeCommandContext()
        let original = context.store.state

        let acknowledgement = context.handler.handle(
            .renamePet(name: "  \n", timestamp: context.now)
        )

        #expect(acknowledgement.errorReason == .invalidPetName)
        #expect(context.store.state == original)
        #expect(context.processedPersistence.ids.isEmpty)
    }

    @Test func renameOverSixteenCharactersIsRejectedWithoutMutation() {
        let context = makeCommandContext()
        let original = context.store.state

        let acknowledgement = context.handler.handle(
            .renamePet(
                name: String(repeating: "A", count: 17),
                timestamp: context.now
            )
        )

        #expect(acknowledgement.errorReason == .invalidPetName)
        #expect(context.store.state == original)
        #expect(context.processedPersistence.ids.isEmpty)
    }

    @Test func duplicateRenameCommandExecutesOnlyOnce() {
        let context = makeCommandContext()
        let command = PetCommand.renamePet(
            name: "Luna",
            id: UUID(),
            timestamp: context.now
        )

        let first = context.handler.handle(command)
        let duplicate = context.handler.handle(command)

        #expect(first.success)
        #expect(duplicate.errorReason == .duplicateCommand)
        #expect(context.store.state.name == "Luna")
        #expect(context.processedPersistence.ids == [command.id])
    }

    @Test func snapshotRequestDoesNotMutateGameplay() {
        let context = makeCommandContext()
        let original = context.store.state

        let acknowledgement = context.handler.handle(
            .requestSnapshot(timestamp: context.now)
        )

        #expect(acknowledgement.success)
        #expect(context.store.state == original)
        #expect(acknowledgement.snapshot?.petName == original.name)
        #expect(acknowledgement.snapshot?.xp == original.xp)
    }

    @Test func duplicateCommandIDExecutesOnlyOnce() {
        let context = makeCommandContext()
        let command = PetCommand.play(id: UUID(), timestamp: context.now)

        let first = context.handler.handle(command)
        let duplicate = context.handler.handle(command)

        #expect(first.success)
        #expect(duplicate.errorReason == .duplicateCommand)
        #expect(context.store.state.xp == 8)
        #expect(context.processedPersistence.ids == [command.id])
    }

    @Test func validPlayCommandUsesExistingGameplay() {
        let context = makeCommandContext()

        let acknowledgement = context.handler.handle(
            .play(timestamp: context.now)
        )

        #expect(acknowledgement.success)
        #expect(context.store.state.hunger == 27)
        #expect(context.store.state.happiness == 92)
        #expect(context.store.state.energy == 62)
        #expect(context.store.state.xp == 8)
        #expect(acknowledgement.snapshot?.xp == 8)
    }

    @Test func validPetCommandUsesExistingGameplay() {
        let context = makeCommandContext()

        let acknowledgement = context.handler.handle(
            .pet(timestamp: context.now)
        )

        #expect(acknowledgement.success)
        #expect(context.store.state.happiness == 84)
        #expect(context.store.state.xp == 2)
    }

    @Test func validFeedCommandResolvesSharedFoodID() {
        let context = makeCommandContext()

        let acknowledgement = context.handler.handle(
            .feed(foodID: "apple", timestamp: context.now)
        )

        #expect(acknowledgement.success)
        #expect(context.store.state.hunger == 10)
        #expect(context.store.state.happiness == 80)
        #expect(context.store.state.xp == 5)
    }

    @Test func invalidFoodIDIsRejectedWithoutMutation() {
        let context = makeCommandContext()
        let original = context.store.state

        let acknowledgement = context.handler.handle(
            .feed(foodID: "unknown", timestamp: context.now)
        )

        #expect(acknowledgement.errorReason == .invalidFoodID)
        #expect(context.store.state == original)
        #expect(context.processedPersistence.ids.isEmpty)
    }

    @Test func malformedAndUnsupportedCommandsAreRejected() {
        let context = makeCommandContext()
        let original = context.store.state
        let malformed = PetCommand(
            id: UUID(),
            type: PetCommand.playType,
            timestamp: context.now,
            foodID: "apple"
        )
        let unsupported = PetCommand(
            id: UUID(),
            type: "dance",
            timestamp: context.now,
            foodID: nil
        )

        #expect(
            context.handler.handle(malformed).errorReason == .malformedCommand
        )
        #expect(
            context.handler.handle(unsupported).errorReason == .unsupportedAction
        )
        #expect(context.store.state == original)
        #expect(context.processedPersistence.ids.isEmpty)
    }

    @Test func processedCommandIDsPruneOldestEntries() {
        let persistence = MemoryProcessedCommandIDPersistence()
        let processedIDs = ProcessedCommandIDs(persistence: persistence)
        let ids = (0..<(ProcessedCommandIDs.limit + 5)).map { _ in UUID() }

        for id in ids {
            processedIDs.record(id)
        }

        #expect(processedIDs.recentIDs.count == ProcessedCommandIDs.limit)
        #expect(processedIDs.contains(ids[0]) == false)
        #expect(processedIDs.contains(ids[5]))
        #expect(persistence.ids == Array(ids.suffix(ProcessedCommandIDs.limit)))
    }

    @Test func petSnapshotMapsOnlyCompanionFields() {
        let timestamp = Date(timeIntervalSince1970: 60_000)
        var pet = PetState.initial
        pet.name = "Pip"
        pet.hunger = 31
        pet.happiness = 86
        pet.energy = 64
        pet.grantXP(230)

        let snapshot = PetSnapshot(
            state: pet,
            todayStepCount: 4_321,
            timestamp: timestamp
        )

        #expect(snapshot.petName == "Pip")
        #expect(snapshot.hunger == 31)
        #expect(snapshot.happiness == 86)
        #expect(snapshot.energy == 64)
        #expect(snapshot.xp == 230)
        #expect(snapshot.level == 3)
        #expect(snapshot.visualState == "happy")
        #expect(snapshot.todayStepCount == 4_321)
        #expect(snapshot.timestamp == timestamp)
        #expect(snapshot.isValid)
    }

    @Test func actionsClampStatsAndGrantXP() {
        var pet = PetState.initial

        for _ in 0..<20 {
            pet.feed(Food.samples[4])
            pet.play()
            pet.pet()
        }

        #expect((0...100).contains(pet.hunger))
        #expect((0...100).contains(pet.happiness))
        #expect((0...100).contains(pet.energy))
        #expect(pet.xp == 300)
        #expect(pet.level == 4)
    }

    @Test func elapsedTimeDecayUsesRealTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        var pet = PetState(
            name: "Mochi",
            hunger: 20,
            happiness: 80,
            energy: 70,
            xp: 0,
            level: 1,
            lastUpdated: start,
            rewardedStepDate: nil,
            rewardedSteps: nil
        )

        pet.applyDecay(at: start.addingTimeInterval(7_200))

        #expect(pet.hunger == 28)
        #expect(pet.happiness == 76)
        #expect(pet.energy == 64)
    }

    @Test func negativeElapsedTimeDoesNotDecayStats() {
        let start = Date(timeIntervalSince1970: 1_000)
        var pet = PetState(
            name: "Mochi",
            hunger: 20,
            happiness: 80,
            energy: 70,
            xp: 0,
            level: 1,
            lastUpdated: start,
            rewardedStepDate: nil,
            rewardedSteps: nil
        )

        pet.applyDecay(at: start.addingTimeInterval(-60))

        #expect(pet.hunger == 20)
        #expect(pet.happiness == 80)
        #expect(pet.energy == 70)
    }

    @Test func userDefaultsPersistenceRoundTrips() throws {
        let suiteName = "PocketPetTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = UserDefaultsPetStatePersistence(defaults: defaults)
        var pet = PetState.initial
        pet.play()

        persistence.save(pet)

        #expect(persistence.load() == pet)
    }

    @Test func stepRewardsDoNotDuplicate() {
        let date = Date(timeIntervalSince1970: 10_000)
        var pet = PetState.initial

        let firstReward = pet.rewardXP(forTodayStepCount: 2_500, at: date)
        let duplicateReward = pet.rewardXP(forTodayStepCount: 2_999, at: date)
        let nextReward = pet.rewardXP(forTodayStepCount: 3_000, at: date)

        #expect(firstReward == 4)
        #expect(duplicateReward == 0)
        #expect(nextReward == 2)
        #expect(pet.xp == 6)
    }

    @Test func stepRewardsResetOnANewDay() {
        let calendar = Calendar(identifier: .gregorian)
        let firstDay = Date(timeIntervalSince1970: 10_000)
        let nextDay = firstDay.addingTimeInterval(86_400)
        var pet = PetState.initial

        _ = pet.rewardXP(
            forTodayStepCount: 3_000,
            at: firstDay,
            calendar: calendar
        )
        let nextDayReward = pet.rewardXP(
            forTodayStepCount: 1_000,
            at: nextDay,
            calendar: calendar
        )

        #expect(nextDayReward == 2)
        #expect(pet.xp == 8)
    }

    @Test func persistedStepCheckpointPreventsDuplicateReward() throws {
        let suiteName = "PocketPetStepTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = UserDefaultsPetStatePersistence(defaults: defaults)
        let date = Date(timeIntervalSince1970: 10_000)
        var pet = PetState.initial

        _ = pet.rewardXP(forTodayStepCount: 5_000, at: date)
        persistence.save(pet)
        var restoredPet = try #require(persistence.load())

        let duplicateReward = restoredPet.rewardXP(
            forTodayStepCount: 5_999,
            at: date
        )

        #expect(duplicateReward == 0)
        #expect(restoredPet.xp == 10)
    }

    @Test func criticalNeedNotifiesOnceUntilRecovery() {
        let now = Date(timeIntervalSince1970: 20_000)
        var pet = PetState.initial
        pet.hunger = PetNotificationConstants.criticalHunger

        let firstPlan = PetNotificationPolicy.plan(
            for: .hunger,
            state: pet,
            checkpoint: PetNotificationCheckpoint(),
            now: now
        )
        let repeatedPlan = PetNotificationPolicy.plan(
            for: .hunger,
            state: pet,
            checkpoint: firstPlan.checkpoint,
            now: now.addingTimeInterval(60)
        )

        #expect(firstPlan.action == .schedule(now.addingTimeInterval(1)))
        #expect(repeatedPlan.action == .cancelPending)
        #expect(repeatedPlan.checkpoint.isEligible == false)
    }

    @Test func sufficientRecoveryRearmsNeedNotification() {
        let now = Date(timeIntervalSince1970: 30_000)
        var checkpoint = PetNotificationCheckpoint()
        checkpoint.isEligible = false
        checkpoint.lastNotificationDate = now.addingTimeInterval(-86_400)
        var pet = PetState.initial
        pet.happiness = PetNotificationConstants.recoveredHappiness

        let recoveredPlan = PetNotificationPolicy.plan(
            for: .happiness,
            state: pet,
            checkpoint: checkpoint,
            now: now
        )

        #expect(recoveredPlan.checkpoint.isEligible)
        guard case .schedule(let date) = recoveredPlan.action else {
            Issue.record("Expected a future one-shot notification")
            return
        }
        #expect(date > now)
    }

    @Test func cooldownDelaysANewNotificationAfterRecovery() {
        let now = Date(timeIntervalSince1970: 40_000)
        let lastNotification = now.addingTimeInterval(-60 * 60)
        let checkpoint = PetNotificationCheckpoint(
            isEligible: true,
            lastNotificationDate: lastNotification,
            scheduledDate: nil
        )
        var pet = PetState.initial
        pet.energy = PetNotificationConstants.criticalEnergy

        let plan = PetNotificationPolicy.plan(
            for: .energy,
            state: pet,
            checkpoint: checkpoint,
            now: now
        )

        #expect(
            plan.action == .schedule(
                lastNotification.addingTimeInterval(
                    PetNotificationConstants.notificationCooldown
                )
            )
        )
    }

    @Test func defaultPetAssetNamesCoverEveryVisualState() {
        let expectedNames: [PetVisualState: String] = [
            .idle: "pet_default_idle",
            .happy: "pet_default_happy",
            .hungry: "pet_default_hungry",
            .sleepy: "pet_default_sleepy",
            .eating: "pet_default_eating",
            .playing: "pet_default_playing",
        ]

        #expect(PetVisualState.allCases.count == expectedNames.count)
        for state in PetVisualState.allCases {
            #expect(PetSpecies.defaultPet.assetName(for: state) == expectedNames[state])
        }
    }

    @Test func onboardingCompletionPersists() throws {
        let suiteName = "PocketPetOnboardingTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = UserDefaultsPetStatePersistence(defaults: defaults)
        let store = PetStateStore(persistence: persistence)

        #expect(store.hasCompletedOnboarding == false)
        #expect(store.completeOnboarding(petName: "Pip"))

        let restoredStore = PetStateStore(persistence: persistence)
        #expect(restoredStore.hasCompletedOnboarding)
    }

    @Test func petNameValidationRejectsInvalidNames() {
        #expect(PetNameRules.validatedName("") == nil)
        #expect(PetNameRules.validatedName("   \n") == nil)
        #expect(
            PetNameRules.validatedName(
                String(repeating: "A", count: PetNameRules.characterLimit + 1)
            ) == nil
        )
        #expect(PetNameRules.validatedName("  Mochi  ") == "Mochi")
    }

    @Test func storedPetNameIsRestored() throws {
        let suiteName = "PocketPetNameTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let persistence = UserDefaultsPetStatePersistence(defaults: defaults)
        let store = PetStateStore(persistence: persistence)

        #expect(store.completeOnboarding(petName: "  Luna  "))

        let restoredStore = PetStateStore(persistence: persistence)
        #expect(restoredStore.state.name == "Luna")
    }

    @Test func existingPetStateMigratesToSharedDefaults() throws {
        let legacySuite = "PocketPetLegacyTests.\(UUID().uuidString)"
        let sharedSuite = "PocketPetSharedTests.\(UUID().uuidString)"
        let legacyDefaults = try #require(
            UserDefaults(suiteName: legacySuite)
        )
        let sharedDefaults = try #require(
            UserDefaults(suiteName: sharedSuite)
        )
        defer {
            legacyDefaults.removePersistentDomain(forName: legacySuite)
            sharedDefaults.removePersistentDomain(forName: sharedSuite)
        }
        var pet = PetState.initial
        pet.name = "Bean"
        PocketPetStorage.saveState(pet, to: legacyDefaults)

        PocketPetStorage.migrateIfNeeded(
            from: legacyDefaults,
            to: sharedDefaults
        )

        #expect(PocketPetStorage.loadState(from: sharedDefaults)?.name == "Bean")
        #expect(PocketPetStorage.loadState(from: legacyDefaults)?.name == "Bean")
    }

    @Test func complicationSnapshotAppliesElapsedDecayReadOnly() {
        let start = Date(timeIntervalSince1970: 50_000)
        let original = PetState(
            name: "Mochi",
            hunger: 68,
            happiness: 80,
            energy: 80,
            xp: 0,
            level: 1,
            lastUpdated: start,
            rewardedStepDate: nil,
            rewardedSteps: nil
        )

        let current = original.decayed(
            at: start.addingTimeInterval(60 * 60)
        )

        #expect(current.status == .hungry)
        #expect(original.hunger == 68)
        #expect(original.lastUpdated == start)
    }

    private func makeCommandContext() -> CommandTestContext {
        let initialState = PetState.initial
        let persistence = MemoryPetStatePersistence(state: initialState)
        let store = PetStateStore(
            persistence: persistence,
            now: initialState.lastUpdated
        )
        let processedPersistence = MemoryProcessedCommandIDPersistence()
        let processedIDs = ProcessedCommandIDs(
            persistence: processedPersistence
        )
        let now = Date(timeIntervalSince1970: 200_000)
        let handler = PetCommandHandler(
            store: store,
            processedIDs: processedIDs,
            now: { now }
        )
        return CommandTestContext(
            store: store,
            handler: handler,
            processedPersistence: processedPersistence,
            now: now
        )
    }
}

@MainActor
private struct CommandTestContext {
    let store: PetStateStore
    let handler: PetCommandHandler
    let processedPersistence: MemoryProcessedCommandIDPersistence
    let now: Date
}

private final class MemoryPetStatePersistence: PetStatePersisting {
    private var state: PetState?

    init(state: PetState? = nil) {
        self.state = state
    }

    func load() -> PetState? { state }
    func save(_ state: PetState) { self.state = state }
    func loadOnboardingCompletion() -> Bool? { true }
    func saveOnboardingCompletion(_ isCompleted: Bool) {}
}

private final class MemoryProcessedCommandIDPersistence: ProcessedCommandIDPersisting {
    var ids: [UUID] = []

    func load() -> [UUID] { ids }
    func save(_ ids: [UUID]) { self.ids = ids }
}
