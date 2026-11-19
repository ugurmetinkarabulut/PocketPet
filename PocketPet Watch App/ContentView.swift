import SwiftUI

struct ContentView: View {
    let store: PetStateStore
    let steps: StepProgressController

    @State private var reaction: PetVisualState?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    petHeader
                    stats
                    actions
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(store.state.name)
            .navigationBarTitleDisplayMode(.inline)
            .task(id: reaction) {
                guard reaction != nil else { return }
                try? await Task.sleep(for: .seconds(1.1))
                guard !Task.isCancelled else { return }
                reaction = nil
            }
        }
    }

    private var petHeader: some View {
        VStack(spacing: 2) {
            Button {
                store.pet()
                reaction = .happy
            } label: {
                PetVisualView(state: reaction ?? store.state.visualState)
                    .frame(height: 92)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Pet \(store.state.name)")
            .accessibilityHint("Increases happiness")

            HStack(spacing: 8) {
                Label("Lv \(store.state.level)", systemImage: "star.fill")
                    .accessibilityLabel("Level \(store.state.level)")

                StepIndicator(controller: steps, petStore: store)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }

    private var stats: some View {
        VStack(spacing: 5) {
            StatRow(
                title: "Hunger",
                symbol: "fork.knife",
                value: store.state.hunger,
                color: .orange
            )
            StatRow(
                title: "Happy",
                symbol: "heart.fill",
                value: store.state.happiness,
                color: .pink
            )
            StatRow(
                title: "Energy",
                symbol: "bolt.fill",
                value: store.state.energy,
                color: .yellow
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var actions: some View {
        HStack(spacing: 8) {
            NavigationLink {
                FoodListView(store: store)
            } label: {
                AdaptiveActionLabel(title: "Feed", symbol: "fork.knife")
            }
            .tint(.orange)
            .accessibilityLabel("Feed")
            .accessibilityHint("Shows available foods")

            Button {
                store.play()
                reaction = .playing
            } label: {
                AdaptiveActionLabel(title: "Play", symbol: "tennisball.fill")
            }
            .tint(.cyan)
            .accessibilityLabel("Play")
            .accessibilityHint("Plays with \(store.state.name)")
        }
        .font(.caption.weight(.semibold))
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
    }
}

private struct AdaptiveActionLabel: View {
    let title: String
    let symbol: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Label(title, systemImage: symbol)
            Image(systemName: symbol)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 32)
    }
}

private struct StatRow: View {
    let title: String
    let symbol: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.caption2)
                .foregroundStyle(color)
                .frame(width: 14)

            ViewThatFits(in: .horizontal) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)

                EmptyView()
            }

            ProgressView(value: value, total: 100)
                .tint(color)
                .layoutPriority(1)

            Text("\(Int(value))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .trailing)
        }
        .frame(minHeight: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("\(Int(value)) out of 100")
    }
}

private struct StepIndicator: View {
    let controller: StepProgressController
    let petStore: PetStateStore

    var body: some View {
        Group {
            switch controller.state {
            case .needsAuthorization:
                Button {
                    Task {
                        await controller.requestAccessAndRefresh(
                            petStore: petStore
                        )
                    }
                } label: {
                    Label("Steps", systemImage: "figure.walk")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .accessibilityLabel("Enable step rewards")
                .accessibilityHint("Requests permission to read today's step count")

            case .loading:
                ProgressView()
                    .controlSize(.mini)
                    .accessibilityLabel("Loading today's steps")

            case .available(let stepCount, let earnedXP):
                Label(
                    stepCount.formatted(.number.notation(.compactName)),
                    systemImage: "figure.walk"
                )
                .accessibilityLabel("\(stepCount) steps today")
                .accessibilityValue(
                    earnedXP > 0 ? "\(earnedXP) XP earned" : "No new XP"
                )

            case .noAccess:
                Label("Off", systemImage: "figure.walk.circle")
                    .foregroundStyle(.orange)
                    .accessibilityLabel("No step access")
                    .accessibilityHint(
                        "Step data is unavailable or Health access is denied"
                    )

            case .unavailable:
                Image(systemName: "heart.slash")
                    .accessibilityLabel("Health data unavailable")

            case .failed:
                Button {
                    Task {
                        await controller.requestAccessAndRefresh(
                            petStore: petStore
                        )
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.orange)
                .accessibilityLabel("Retry step update")
            }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: 28)
        .background(.thinMaterial, in: Capsule())
    }
}

private struct FoodListView: View {
    @Environment(\.dismiss) private var dismiss

    let store: PetStateStore
    @State private var selectedFood: Food?

    var body: some View {
        Group {
            if let selectedFood {
                eatingReaction(for: selectedFood)
            } else {
                List(Food.samples) { food in
                    Button {
                        store.feed(food)
                        selectedFood = food
                    } label: {
                        FoodRow(food: food)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Feed \(food.name)")
                    .accessibilityValue("Reduces hunger by \(food.hungerRestore)")
                }
                .listStyle(.carousel)
                .navigationTitle("Food")
            }
        }
        .task(id: selectedFood?.id) {
            guard selectedFood != nil else { return }
            try? await Task.sleep(for: .seconds(1.35))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    private func eatingReaction(for food: Food) -> some View {
        VStack(spacing: 8) {
            PetVisualView(state: .eating)
                .frame(height: 112)

            Text("\(food.placeholder) Yum!")
                .font(.headline)
                .transition(.scale.combined(with: .opacity))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarBackButtonHidden()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(store.state.name) is eating \(food.name)")
    }
}

private struct FoodRow: View {
    let food: Food

    var body: some View {
        HStack(spacing: 10) {
            Text(food.placeholder)
                .font(.title2)
                .frame(width: 30)
                .accessibilityHidden(true)

            Text(food.name)
                .font(.body.weight(.medium))
                .lineLimit(1)

            Spacer(minLength: 4)

            Text("−\(food.hungerRestore)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 36)
        .contentShape(Rectangle())
    }
}

#Preview("Home") {
    ContentView(
        store: PetStateStore(persistence: PreviewPetStatePersistence()),
        steps: StepProgressController(
            service: PreviewStepDataService(),
            defaults: UserDefaults(suiteName: "PocketPetPreview") ?? .standard
        )
    )
}
