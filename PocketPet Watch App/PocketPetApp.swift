//
//  PocketPetApp.swift
//  PocketPet Watch App
//
//  Created by Uğur Metin Karabulut on 20.09.2026.
//

import SwiftUI

@main
struct PocketPet_Watch_AppApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var petStore = PetStateStore()
    @State private var steps = StepProgressController()
    @State private var connectivity = WatchConnectivityController()
    private let notifications = PetNotificationManager()

    var body: some Scene {
        WindowGroup {
            Group {
                if petStore.hasCompletedOnboarding {
                    ContentView(store: petStore, steps: steps)
                        .task {
                            petStore.connectSnapshotSender(connectivity)
                            connectivity.connectCommandHandler(to: petStore)
                            connectivity.activate()
                            await notifications.start(for: petStore.state)
                            await steps.refresh(petStore: petStore)
                        }
                        .onChange(of: petStore.state) { _, state in
                            Task {
                                await notifications.update(for: state)
                            }
                        }
                        .onChange(of: scenePhase) { _, newPhase in
                            guard newPhase == .active else { return }
                            petStore.refresh()
                            petStore.sendLatestSnapshot()
                            Task {
                                await steps.refresh(petStore: petStore)
                            }
                        }
                } else {
                    OnboardingView(store: petStore)
                }
            }
        }
    }
}
