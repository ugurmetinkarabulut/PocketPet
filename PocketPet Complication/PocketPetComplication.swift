import SwiftUI
import UIKit
import WidgetKit

private let complicationKind = "PocketPetComplication"

struct PetComplicationEntry: TimelineEntry {
    let date: Date
    let state: PetState
}

struct PetComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetComplicationEntry {
        PetComplicationEntry(date: .now, state: .initial)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (PetComplicationEntry) -> Void
    ) {
        completion(entry(at: .now))
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<PetComplicationEntry>) -> Void
    ) {
        let now = Date.now
        let entries = stride(from: 0, through: 12, by: 2).map { hour in
            entry(at: now.addingTimeInterval(TimeInterval(hour) * 60 * 60))
        }
        completion(
            Timeline(
                entries: entries,
                policy: .after(now.addingTimeInterval(12 * 60 * 60))
            )
        )
    }

    private func entry(at date: Date) -> PetComplicationEntry {
        let storedState = PocketPetStorage.appGroupDefaults().flatMap {
            PocketPetStorage.loadState(from: $0)
        } ?? .initial
        return PetComplicationEntry(
            date: date,
            state: storedState.decayed(at: date)
        )
    }
}

struct PetComplicationEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PetComplicationEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                CircularPetComplication(state: entry.state)
            case .accessoryRectangular:
                RectangularPetComplication(state: entry.state)
            default:
                EmptyView()
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

private struct CircularPetComplication: View {
    let state: PetState

    var body: some View {
        Gauge(value: state.statusSeverity, in: 0...100) {
            EmptyView()
        } currentValueLabel: {
            VStack(spacing: -2) {
                ComplicationPetVisual(state: state.visualState, size: 24)
                Image(systemName: state.status.symbolName)
                    .font(.system(size: 9, weight: .semibold))
                    .widgetAccentable()
            }
        }
        .gaugeStyle(.accessoryCircular)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(state.name), \(state.status.shortLabel)"
        )
        .accessibilityValue(
            "Status severity \(Int(state.statusSeverity)) out of 100"
        )
    }
}

private struct RectangularPetComplication: View {
    let state: PetState

    var body: some View {
        HStack(spacing: 6) {
            ComplicationPetVisual(state: state.visualState, size: 34)

            VStack(alignment: .leading, spacing: 1) {
                Text(state.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Label(state.status.shortLabel, systemImage: state.status.symbolName)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .widgetAccentable()
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ComplicationPetVisual: View {
    let state: PetVisualState
    let size: CGFloat

    var body: some View {
        if let image = UIImage(
            named: PetSpecies.defaultPet.assetName(for: state)
        ) {
            Image(uiImage: image)
                .resizable()
                .widgetAccentedRenderingMode(.accentedDesaturated)
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(state.placeholder)
                .font(.system(size: size * 0.72))
        }
    }
}

struct PocketPetComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: complicationKind,
            provider: PetComplicationProvider()
        ) { entry in
            PetComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("PocketPet")
        .description("See your pet's most important need.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}

@main
struct PocketPetComplicationBundle: WidgetBundle {
    var body: some Widget {
        PocketPetComplication()
    }
}

#Preview(as: .accessoryCircular) {
    PocketPetComplication()
} timeline: {
    PetComplicationEntry(date: .now, state: .initial)
}

#Preview(as: .accessoryRectangular) {
    PocketPetComplication()
} timeline: {
    PetComplicationEntry(date: .now, state: .initial)
}
