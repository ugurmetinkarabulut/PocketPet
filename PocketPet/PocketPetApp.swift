//
//  PocketPetApp.swift
//  PocketPet
//
//  Created by Uğur Metin Karabulut on 20.09.2026.
//

import SwiftUI

@main
struct PocketPetApp: App {
    @State private var petStore: PhonePetStore
    @State private var connectivity: PhoneConnectivityController

    init() {
        let petStore = PhonePetStore()
        _petStore = State(initialValue: petStore)
        _connectivity = State(
            initialValue: PhoneConnectivityController(store: petStore)
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(store: petStore, connectivity: connectivity)
                .task {
                    connectivity.activate()
                }
        }
    }
}
