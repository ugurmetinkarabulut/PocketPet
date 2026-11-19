import SwiftUI

struct PetProgressView: View {
    let store: PhonePetStore

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot = store.snapshot {
                    progressContent(snapshot)
                } else {
                    ContentUnavailableView(
                        "Waiting for Progress",
                        systemImage: "applewatch.radiowaves.left.and.right",
                        description: Text(
                            "Progress will appear after the first snapshot from Apple Watch."
                        )
                    )
                }
            }
            .navigationTitle("Progress")
        }
    }

    private func progressContent(_ snapshot: PetSnapshot) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                levelSummary(snapshot)
                currentSummary(snapshot)

                if let trend = recentTrend {
                    trendSection(trend)
                }

                activitySection
            }
            .padding()
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func levelSummary(_ snapshot: PetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CURRENT LEVEL")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(snapshot.level.formatted())
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                }
                Spacer()
                Text("\(xpInLevel(snapshot)) / 100 XP")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: Double(xpInLevel(snapshot)), total: 100)
                .tint(.indigo)
                .accessibilityLabel("Experience toward level \(snapshot.level + 1)")
                .accessibilityValue("\(xpInLevel(snapshot)) out of 100")
        }
        .padding(20)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
    }

    private func currentSummary(_ snapshot: PetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.title3.bold())

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    summaryItem(
                        title: "Needs",
                        value: needsSummary(snapshot),
                        symbol: needsSymbol(snapshot)
                    )
                    summaryItem(
                        title: "Steps",
                        value: snapshot.todayStepCount?.formatted() ?? "Unavailable",
                        symbol: "figure.walk"
                    )
                }

                VStack(spacing: 12) {
                    summaryItem(
                        title: "Needs",
                        value: needsSummary(snapshot),
                        symbol: needsSymbol(snapshot)
                    )
                    summaryItem(
                        title: "Steps",
                        value: snapshot.todayStepCount?.formatted() ?? "Unavailable",
                        symbol: "figure.walk"
                    )
                }
            }
        }
    }

    private func summaryItem(
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 74)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(value)")
    }

    private func trendSection(_ trend: PetStatTrend) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent stat trend")
                .font(.title3.bold())

            HStack(spacing: 0) {
                trendMetric("Hunger", value: trend.hunger, color: .orange)
                Divider()
                trendMetric("Happiness", value: trend.happiness, color: .pink)
                Divider()
                trendMetric("Energy", value: trend.energy, color: .yellow)
            }
            .frame(minHeight: 64)
            .accessibilityElement(children: .contain)
        }
    }

    private func trendMetric(
        _ title: String,
        value: Int,
        color: Color
    ) -> some View {
        VStack(spacing: 5) {
            Image(systemName: trendSymbol(value))
                .foregroundStyle(value == 0 ? .secondary : color)
            Text(value.formatted(.number.sign(strategy: .always())))
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title) changed by \(value)")
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent activity")
                .font(.title3.bold())

            if recentActivities.isEmpty {
                ContentUnavailableView(
                    "No Recent Activity",
                    systemImage: "clock",
                    description: Text(
                        "Meaningful changes will appear after more Watch snapshots arrive."
                    )
                )
                .frame(maxWidth: .infinity, minHeight: 190)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recentActivities.prefix(8).enumerated()), id: \.element.id) { index, activity in
                        activityRow(activity)
                        if index < min(recentActivities.count, 8) - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }
            }
        }
    }

    private func activityRow(_ activity: PetActivity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: activitySymbol(activity.kind))
                .foregroundStyle(activityColor(activity.kind))
                .frame(width: 32, height: 32)
                .background(activityColor(activity.kind).opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(activityTitle(activity.kind))
                    .font(.subheadline.weight(.medium))
                Text(activity.date, format: .relative(presentation: .named))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }

    private var recentActivities: [PetActivity] {
        PetActivityDeriver.activities(from: store.history)
    }

    private var recentTrend: PetStatTrend? {
        PetStatTrend.derive(from: Array(store.history.suffix(8)))
    }

    private func xpInLevel(_ snapshot: PetSnapshot) -> Int {
        snapshot.xp % 100
    }

    private func needsSummary(_ snapshot: PetSnapshot) -> String {
        var needs: [String] = []
        if snapshot.hunger >= 70 { needs.append("Hungry") }
        if snapshot.happiness <= 30 { needs.append("Needs attention") }
        if snapshot.energy <= 30 { needs.append("Low energy") }
        return needs.isEmpty ? "Steady" : needs.joined(separator: ", ")
    }

    private func needsSymbol(_ snapshot: PetSnapshot) -> String {
        if snapshot.hunger >= 70 { return "fork.knife" }
        if snapshot.energy <= 30 { return "moon.zzz.fill" }
        if snapshot.happiness <= 30 { return "heart.slash" }
        return "checkmark.circle.fill"
    }

    private func trendSymbol(_ value: Int) -> String {
        if value > 0 { return "arrow.up.right" }
        if value < 0 { return "arrow.down.right" }
        return "arrow.right"
    }

    private func activityTitle(_ kind: PetActivityKind) -> String {
        switch kind {
        case .levelIncreased(let level):
            "Reached level \(level)"
        case .xpIncreased(let amount):
            "Gained \(amount) XP"
        case .becameHungry:
            "Became hungry"
        case .recoveredFromHunger:
            "Recovered from hunger"
        case .happinessChanged(let amount):
            amount > 0
                ? "Happiness improved by \(amount)"
                : "Happiness dropped by \(abs(amount))"
        case .energyChanged(let amount):
            amount > 0
                ? "Energy improved by \(amount)"
                : "Energy dropped by \(abs(amount))"
        case .stepMilestone(let steps):
            "Reached \(steps.formatted()) steps"
        }
    }

    private func activitySymbol(_ kind: PetActivityKind) -> String {
        switch kind {
        case .levelIncreased: "star.fill"
        case .xpIncreased: "sparkles"
        case .becameHungry: "fork.knife"
        case .recoveredFromHunger: "checkmark.circle.fill"
        case .happinessChanged: "heart.fill"
        case .energyChanged: "bolt.fill"
        case .stepMilestone: "figure.walk"
        }
    }

    private func activityColor(_ kind: PetActivityKind) -> Color {
        switch kind {
        case .levelIncreased, .xpIncreased: .indigo
        case .becameHungry: .orange
        case .recoveredFromHunger: .green
        case .happinessChanged: .pink
        case .energyChanged: .yellow
        case .stepMilestone: .cyan
        }
    }
}
