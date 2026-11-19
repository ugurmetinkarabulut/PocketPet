import Foundation
import SwiftUI

struct SettingsView: View {
    let store: PhonePetStore
    let connectivity: PhoneConnectivityController
    private let versionInfo = AppVersionInfo()

    var body: some View {
        NavigationStack {
            Form {
                petSection
                watchSection
                healthSection
                notificationsSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    private var petSection: some View {
        Section("Pet") {
            HStack(spacing: 14) {
                Image(systemName: "pawprint.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 44, height: 44)
                    .background(.tint.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(store.snapshot?.petName ?? "Waiting for Apple Watch")
                        .font(.headline)
                    if let level = store.snapshot?.level {
                        Text("Level \(level)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            if let snapshot = store.snapshot {
                NavigationLink("Rename Pet") {
                    RenamePetView(
                        currentName: snapshot.petName,
                        connectivity: connectivity
                    )
                }
            } else {
                LabeledContent("Rename Pet", value: "Watch data required")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var watchSection: some View {
        Section {
            LabeledContent("Paired Watch", value: pairedWatchStatus)
            LabeledContent("Watch App", value: watchAppStatus)
            LabeledContent("Connection", value: activationStatus)
            LabeledContent("Reachability", value: reachabilityStatus)

            LabeledContent("Last Synchronization") {
                if let date = connectivity.lastSuccessfulSynchronization {
                    Text(date, format: .relative(presentation: .named))
                } else {
                    Text("Not yet this session")
                }
            }

            Button {
                connectivity.syncNow()
            } label: {
                HStack {
                    Text("Sync Now")
                    Spacer()
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(!connectivity.canSendCommand)
            .accessibilityHint("Requests the latest pet snapshot from Apple Watch")

            syncFeedback
        } header: {
            Text("Apple Watch")
        } footer: {
            Text("Sync Now requests the latest snapshot without changing your pet.")
        }
    }

    private var healthSection: some View {
        Section {
            if let snapshot = store.snapshot,
               let steps = snapshot.todayStepCount {
                LabeledContent("Today's Steps", value: steps.formatted())
                LabeledContent("Step Integration", value: "Available")
                LabeledContent("Last Step Data") {
                    Text(snapshot.timestamp, format: .relative(presentation: .named))
                }
            } else {
                LabeledContent("Today's Steps", value: "Unavailable")
                LabeledContent(
                    "Step Integration",
                    value: "Not currently available"
                )
            }
        } header: {
            Text("Health & Activity")
        } footer: {
            Text("Step data comes from Apple Watch. PocketPet does not read Health data on iPhone.")
        }
    }

    private var notificationsSection: some View {
        Section {
            LabeledContent("Pet Notifications", value: "Apple Watch only")
        } header: {
            Text("Notifications")
        } footer: {
            Text("Notification authorization is managed on Apple Watch and is not shared with the iPhone app.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("App", value: versionInfo.appName)
            LabeledContent("Version", value: versionInfo.version)
            LabeledContent("Build", value: versionInfo.build)
        }
    }

    @ViewBuilder
    private var syncFeedback: some View {
        switch connectivity.commandState {
        case .sending(let command)
            where command.type == PetCommand.requestSnapshotType:
            Text("Requesting the latest snapshot…")
                .font(.footnote)
                .foregroundStyle(.secondary)

        case .succeeded(let command)
            where command.type == PetCommand.requestSnapshotType:
            Label("Synchronization complete", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.green)

        case .failed(let command?, let reason)
            where command.type == PetCommand.requestSnapshotType:
            Label(commandFailureMessage(reason), systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(.orange)

        default:
            EmptyView()
        }
    }

    private var isSyncing: Bool {
        guard case .sending(let command) = connectivity.commandState else {
            return false
        }
        return command.type == PetCommand.requestSnapshotType
    }

    private var pairedWatchStatus: String {
        switch connectivity.activationState {
        case .unsupported:
            return "Unavailable"
        case .notActivated, .activating:
            return connectivity.isWatchPaired ? "Paired" : "Checking…"
        case .inactive, .activated, .failed:
            return connectivity.isWatchPaired ? "Paired" : "Not paired"
        }
    }

    private var watchAppStatus: String {
        if !connectivity.isWatchPaired {
            return pairedWatchStatus == "Checking…" ? "Checking…" : "Unavailable"
        }
        return connectivity.isWatchAppInstalled ? "Installed" : "Not installed"
    }

    private var activationStatus: String {
        switch connectivity.activationState {
        case .unsupported: "Unavailable"
        case .notActivated: "Not started"
        case .activating: "Connecting…"
        case .inactive: "Inactive"
        case .activated: "Active"
        case .failed: "Unavailable"
        }
    }

    private var reachabilityStatus: String {
        connectivity.isWatchReachable ? "Reachable" : "Not reachable"
    }
}

private struct RenamePetView: View {
    let connectivity: PhoneConnectivityController

    @State private var petName: String

    init(currentName: String, connectivity: PhoneConnectivityController) {
        self.connectivity = connectivity
        _petName = State(initialValue: currentName)
    }

    var body: some View {
        Form {
            Section {
                TextField("Pet name", text: $petName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .onSubmit(save)
                    .onChange(of: petName) { _, newName in
                        let limitedName = PetNameRules.limitedName(newName)
                        if limitedName != newName {
                            petName = limitedName
                        }
                    }

                HStack {
                    Text("Up to \(PetNameRules.characterLimit) characters")
                    Spacer()
                    Text("\(petName.count)/\(PetNameRules.characterLimit)")
                        .monospacedDigit()
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section {
                Button("Save Name", action: save)
                    .disabled(
                        PetNameRules.validatedName(petName) == nil
                            || !connectivity.canSendCommand
                    )

                renameFeedback
            } footer: {
                Text("Apple Watch validates and saves the name, then sends the accepted pet snapshot back to this iPhone.")
            }
        }
        .navigationTitle("Rename Pet")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        guard PetNameRules.validatedName(petName) != nil else { return }
        connectivity.sendRenamePet(name: petName)
    }

    @ViewBuilder
    private var renameFeedback: some View {
        switch connectivity.commandState {
        case .sending(let command) where command.type == PetCommand.renamePetType:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Sending to Apple Watch…")
            }
            .font(.footnote)

        case .succeeded(let command) where command.type == PetCommand.renamePetType:
            Label("Name updated from Apple Watch", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.green)

        case .failed(let command?, let reason)
            where command.type == PetCommand.renamePetType:
            Label(commandFailureMessage(reason), systemImage: "exclamationmark.circle")
                .font(.footnote)
                .foregroundStyle(.orange)

        default:
            EmptyView()
        }
    }
}

struct AppVersionInfo: Equatable {
    let appName: String
    let version: String
    let build: String

    init(bundle: Bundle = .main) {
        self.init(infoDictionary: bundle.infoDictionary ?? [:])
    }

    init(infoDictionary: [String: Any]) {
        appName = (infoDictionary["CFBundleDisplayName"] as? String)
            ?? (infoDictionary["CFBundleName"] as? String)
            ?? "—"
        version = (infoDictionary["CFBundleShortVersionString"] as? String)
            ?? "—"
        build = (infoDictionary["CFBundleVersion"] as? String)
            ?? "—"
    }
}
