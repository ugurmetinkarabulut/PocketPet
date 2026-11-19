import SwiftUI
import WidgetKit

struct PocketPetWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetPetSnapshot?
}

struct PocketPetWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PocketPetWidgetEntry {
        PocketPetWidgetEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (PocketPetWidgetEntry) -> Void
    ) {
        completion(
            PocketPetWidgetEntry(
                date: .now,
                snapshot: context.isPreview ? .placeholder : loadSnapshot()
            )
        )
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<PocketPetWidgetEntry>) -> Void
    ) {
        let now = Date()
        completion(
            Timeline(
                entries: [
                    PocketPetWidgetEntry(date: now, snapshot: loadSnapshot()),
                ],
                policy: .after(now.addingTimeInterval(6 * 60 * 60))
            )
        )
    }

    private func loadSnapshot() -> WidgetPetSnapshot? {
        UserDefaultsWidgetSnapshotStore.appGroupStore()?.load()
    }
}

struct PocketPetWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PocketPetWidgetEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                switch family {
                case .systemMedium:
                    MediumPetWidget(snapshot: snapshot)
                default:
                    SmallPetWidget(snapshot: snapshot)
                }
            } else {
                EmptyPetWidget()
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.18),
                    Color(.secondarySystemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private struct SmallPetWidget: View {
    let snapshot: WidgetPetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.petName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("Lv \(snapshot.level)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                PetPlaceholder(visualState: snapshot.visualState, size: 52)
                StatusLabel(status: .mostImportant(for: snapshot))
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(snapshot.petName), level \(snapshot.level), \(PetWidgetStatus.mostImportant(for: snapshot).title)"
        )
    }
}

private struct MediumPetWidget: View {
    let snapshot: WidgetPetSnapshot

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 6) {
                PetPlaceholder(visualState: snapshot.visualState, size: 62)
                Text(snapshot.petName)
                    .font(.headline)
                    .lineLimit(1)
            }
            .frame(width: 78)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Level \(snapshot.level)")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(xpInLevel) / 100 XP")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: Double(xpInLevel), total: 100)
                    .tint(.accentColor)

                HStack(spacing: 6) {
                    StatPill(title: "Hunger", value: snapshot.hunger, symbol: "fork.knife")
                    StatPill(title: "Happy", value: snapshot.happiness, symbol: "heart.fill")
                    StatPill(title: "Energy", value: snapshot.energy, symbol: "bolt.fill")
                }

                if let steps = snapshot.todayStepCount {
                    Label("\(steps.formatted()) steps today", systemImage: "figure.walk")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var xpInLevel: Int { snapshot.xp % 100 }

    private var accessibilitySummary: String {
        var summary = "\(snapshot.petName), level \(snapshot.level), \(xpInLevel) of 100 XP. Hunger \(Int(snapshot.hunger)), happiness \(Int(snapshot.happiness)), energy \(Int(snapshot.energy))."
        if let steps = snapshot.todayStepCount {
            summary += " \(steps) steps today."
        }
        return summary
    }
}

private struct PetPlaceholder: View {
    let visualState: String
    let size: CGFloat

    var body: some View {
        Image(systemName: symbolName)
            .font(.system(size: size * 0.48, weight: .medium))
            .foregroundStyle(.tint)
            .frame(width: size, height: size)
            .background(.tint.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }

    private var symbolName: String {
        switch visualState.lowercased() {
        case "sleeping", "tired": "moon.stars.fill"
        case "sad", "hungry": "pawprint.fill"
        default: "dog.fill"
        }
    }
}

private struct StatusLabel: View {
    let status: PetWidgetStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: status.symbolName)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(status.title)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
        }
    }
}

private struct StatPill: View {
    let title: String
    let value: Double
    let symbol: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: symbol)
                .font(.caption2)
            Text("\(Int(value))")
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct EmptyPetWidget: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.title)
                .foregroundStyle(.tint)
            Text("Meet your PocketPet")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Open PocketPet on Apple Watch to sync your pet.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

@main
struct PocketPetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: PocketPetWidgetConfiguration.kind,
            provider: PocketPetWidgetProvider()
        ) { entry in
            PocketPetWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("PocketPet")
        .description("See your pet's latest synced status.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private extension WidgetPetSnapshot {
    static let placeholder = WidgetPetSnapshot(
        snapshot: PetSnapshot(
            version: 1,
            timestamp: .now,
            petName: "Mochi",
            hunger: 28,
            happiness: 84,
            energy: 72,
            xp: 145,
            level: 2,
            visualState: "happy",
            todayStepCount: 4_321
        )
    )
}
