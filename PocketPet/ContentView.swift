import SwiftUI

struct ContentView: View {
    let store: PhonePetStore
    let connectivity: PhoneConnectivityController

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView(store: store, connectivity: connectivity)
            }

            Tab("Progress", systemImage: "chart.line.uptrend.xyaxis") {
                PetProgressView(store: store)
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView(store: store, connectivity: connectivity)
            }
        }
    }
}

private struct HomeView: View {
    let store: PhonePetStore
    let connectivity: PhoneConnectivityController

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot = store.snapshot {
                    PetOverview(
                        snapshot: snapshot,
                        connectionState: store.connectionState,
                        isShowingCachedSnapshot: store.isShowingCachedSnapshot,
                        connectivity: connectivity
                    )
                } else {
                    EmptyPetState(connectionState: store.connectionState)
                }
            }
            .navigationTitle("PocketPet")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct PetOverview: View {
    let snapshot: PetSnapshot
    let connectionState: WatchConnectionState
    let isShowingCachedSnapshot: Bool
    let connectivity: PhoneConnectivityController

    @State private var presentedSheet: HomeSheet?

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                syncStatus
                petHero
                actions
                commandFeedback
                progressCard
                needsCard

                if let steps = snapshot.todayStepCount {
                    stepsCard(steps)
                }

                if let message = connectionMessage {
                    Label(message, systemImage: "wifi.exclamationmark")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .accessibilityLabel(message)
                }
            }
            .padding()
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $presentedSheet) { sheet in
            switch sheet {
            case .food:
                FoodSelectionView(connectivity: connectivity)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var syncStatus: some View {
        HStack(spacing: 8) {
            Image(
                systemName: isShowingCachedSnapshot
                    ? "clock.arrow.circlepath"
                    : "checkmark.icloud"
            )
            .foregroundStyle(isShowingCachedSnapshot ? .orange : .green)

            Text(
                isShowingCachedSnapshot
                    ? "Saved Watch snapshot"
                    : "Synced from Apple Watch"
            )
            .font(.subheadline.weight(.semibold))

            Spacer()

            Text(snapshot.timestamp, format: .relative(presentation: .named))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(isShowingCachedSnapshot ? "Saved Watch snapshot" : "Synced from Apple Watch"), \(snapshot.timestamp.formatted(date: .abbreviated, time: .shortened))"
        )
    }

    private var petHero: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(.tint.opacity(0.12))

                Circle()
                    .fill(.background.opacity(0.9))
                    .frame(width: 190, height: 190)
                    .shadow(color: .black.opacity(0.08), radius: 22, y: 10)

                Image(systemName: visualSymbol)
                    .font(.system(size: 92, weight: .medium))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
            .frame(height: 270)

            VStack(spacing: 4) {
                Text(snapshot.petName)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(snapshot.visualState.capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snapshot.petName), \(snapshot.visualState)")
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Level \(snapshot.level)", systemImage: "star.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(xpInLevel) / 100 XP")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(xpInLevel), total: 100)
                .tint(.indigo)
                .accessibilityLabel("Experience progress")
                .accessibilityValue("\(xpInLevel) out of 100")
        }
        .cardStyle()
    }

    private var actions: some View {
        HStack(spacing: 10) {
            actionButton(title: "Feed", symbol: "fork.knife", tint: .orange) {
                presentedSheet = .food
            }
            actionButton(title: "Play", symbol: "tennisball.fill", tint: .cyan) {
                connectivity.sendPlay()
            }
            actionButton(title: "Pet", symbol: "hand.tap.fill", tint: .pink) {
                connectivity.sendPet()
            }
        }
        .disabled(!connectivity.canSendGameplayCommand)
    }

    private func actionButton(
        title: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 54)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .accessibilityLabel(title)
        .accessibilityHint("Performs this action on Apple Watch")
    }

    @ViewBuilder
    private var commandFeedback: some View {
        switch connectivity.commandState {
        case .idle:
            EmptyView()

        case .sending(let command):
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Sending \(actionName(command).lowercased()) to Apple Watch…")
            }
            .font(.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

        case .succeeded(let command):
            Label(
                "\(actionName(command)) completed on Apple Watch",
                systemImage: "checkmark.circle.fill"
            )
            .font(.footnote)
            .foregroundStyle(.green)
            .frame(maxWidth: .infinity, alignment: .leading)

        case .failed(_, let reason):
            Label(commandFailureMessage(reason), systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var needsCard: some View {
        VStack(spacing: 18) {
            PetStatRow(
                title: "Hunger",
                symbol: "fork.knife",
                value: snapshot.hunger,
                color: .orange
            )
            PetStatRow(
                title: "Happiness",
                symbol: "heart.fill",
                value: snapshot.happiness,
                color: .pink
            )
            PetStatRow(
                title: "Energy",
                symbol: "bolt.fill",
                value: snapshot.energy,
                color: .yellow
            )
        }
        .cardStyle()
    }

    private func stepsCard(_ steps: Int) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.walk")
                .font(.title2)
                .foregroundStyle(.cyan)
                .frame(width: 38, height: 38)
                .background(.cyan.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("Today's steps")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(steps.formatted())
                    .font(.title3.bold().monospacedDigit())
            }
            Spacer()
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(steps) steps today")
    }

    private var xpInLevel: Int {
        snapshot.xp % 100
    }

    private var visualSymbol: String {
        switch snapshot.visualState {
        case "happy", "playing": "pawprint.fill"
        case "hungry": "fork.knife.circle.fill"
        case "sleepy": "moon.zzz.fill"
        case "eating": "takeoutbag.and.cup.and.straw.fill"
        default: "pawprint.fill"
        }
    }

    private var connectionMessage: String? {
        switch connectionState {
        case .ready(let isReachable):
            isReachable ? nil : "Apple Watch is not currently reachable."
        case .activating:
            "Connecting to Apple Watch…"
        case .unsupported:
            "Watch connectivity is unavailable on this iPhone."
        case .noPairedWatch:
            "No Apple Watch is paired with this iPhone."
        case .watchAppNotInstalled:
            "Install PocketPet on Apple Watch to receive updates."
        case .unavailable:
            "The latest Watch update is temporarily unavailable."
        }
    }
}

private enum HomeSheet: String, Identifiable {
    case food
    var id: String { rawValue }
}

private struct FoodSelectionView: View {
    @Environment(\.dismiss) private var dismiss

    let connectivity: PhoneConnectivityController

    var body: some View {
        NavigationStack {
            List(Food.samples) { food in
                Button {
                    connectivity.sendFeed(foodID: food.id)
                    dismiss()
                } label: {
                    HStack(spacing: 14) {
                        Text(food.placeholder)
                            .font(.title2)
                            .accessibilityHidden(true)
                        Text(food.name)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .disabled(!connectivity.canSendGameplayCommand)
                .accessibilityLabel("Feed \(food.name)")
            }
            .navigationTitle("Choose Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

func actionName(_ command: PetCommand) -> String {
    switch command.type {
    case PetCommand.feedType: "Feed"
    case PetCommand.playType: "Play"
    case PetCommand.petType: "Pet"
    case PetCommand.renamePetType: "Rename"
    case PetCommand.requestSnapshotType: "Sync"
    default: "Action"
    }
}

func commandFailureMessage(_ reason: PetCommandErrorReason) -> String {
    switch reason {
    case .watchUnavailable, .transportFailure:
        "Apple Watch must be reachable. The action was not queued."
    case .invalidFoodID:
        "That food is no longer available on Apple Watch."
    case .invalidPetName:
        "Use a pet name between 1 and 16 characters."
    case .duplicateCommand:
        "Apple Watch already handled this action."
    case .expiredCommand:
        "The action expired before Apple Watch received it."
    case .malformedCommand, .unsupportedAction, .invalidResponse:
        "Apple Watch could not complete the action. Please try again."
    }
}

private struct PetStatRow: View {
    let title: String
    let symbol: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label(title, systemImage: symbol)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(Int(value))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: value, total: 100)
                .tint(color)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value)) out of 100")
    }
}

private struct EmptyPetState: View {
    let connectionState: WatchConnectionState

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: symbol,
            description: Text(message)
        )
        .padding()
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        switch connectionState {
        case .unsupported: "Watch Not Supported"
        case .noPairedWatch: "No Paired Apple Watch"
        case .watchAppNotInstalled: "Watch App Not Installed"
        case .unavailable: "Connection Unavailable"
        case .activating, .ready: "Waiting for PocketPet"
        }
    }

    private var symbol: String {
        switch connectionState {
        case .unsupported, .noPairedWatch: "applewatch.slash"
        case .watchAppNotInstalled: "applewatch.badge.exclamationmark"
        case .unavailable: "wifi.exclamationmark"
        case .activating, .ready: "applewatch.radiowaves.left.and.right"
        }
    }

    private var message: String {
        switch connectionState {
        case .unsupported:
            "This device cannot connect to an Apple Watch."
        case .noPairedWatch:
            "Pair an Apple Watch to see your pet here."
        case .watchAppNotInstalled:
            "Install and open PocketPet on your Apple Watch."
        case .unavailable:
            "PocketPet still works, and will update when connectivity returns."
        case .activating, .ready:
            "Open PocketPet on your Apple Watch. Your latest pet snapshot will appear automatically."
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(18)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
    }
}

#Preview("Synced") {
    let store = PhonePetStore.preview(snapshot: .preview, cached: false)
    ContentView(
        store: store,
        connectivity: PhoneConnectivityController(store: store, session: nil)
    )
}

#Preview("Waiting") {
    let store = PhonePetStore.preview(snapshot: nil, cached: false)
    ContentView(
        store: store,
        connectivity: PhoneConnectivityController(store: store, session: nil)
    )
}

private extension PhonePetStore {
    static func preview(snapshot: PetSnapshot?, cached: Bool) -> PhonePetStore {
        let store = PhonePetStore(
            cache: PreviewSnapshotCache(snapshot: cached ? snapshot : nil),
            historyPersistence: PreviewHistoryPersistence(
                snapshots: snapshot.map { [$0] } ?? []
            )
        )
        if let snapshot, !cached { _ = store.accept(snapshot) }
        store.updateConnectionState(.ready(isReachable: true))
        return store
    }
}

private struct PreviewSnapshotCache: PetSnapshotCaching {
    let snapshot: PetSnapshot?
    func load() -> PetSnapshot? { snapshot }
    func save(_ snapshot: PetSnapshot) {}
}

private struct PreviewHistoryPersistence: PetSnapshotHistoryPersisting {
    let snapshots: [PetSnapshot]
    func load() -> [PetSnapshot] { snapshots }
    func save(_ snapshots: [PetSnapshot]) {}
}

private extension PetSnapshot {
    static let preview = PetSnapshot(
        version: 1,
        timestamp: .now.addingTimeInterval(-75),
        petName: "Mochi",
        hunger: 24,
        happiness: 82,
        energy: 68,
        xp: 245,
        level: 3,
        visualState: "happy",
        todayStepCount: 4_820
    )
}
