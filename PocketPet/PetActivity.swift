import Foundation

enum PetActivityKind: Equatable {
    case levelIncreased(to: Int)
    case xpIncreased(by: Int)
    case becameHungry
    case recoveredFromHunger
    case happinessChanged(by: Int)
    case energyChanged(by: Int)
    case stepMilestone(Int)
}

struct PetActivity: Identifiable, Equatable {
    let id: String
    let date: Date
    let kind: PetActivityKind
}

enum PetActivityDeriver {
    private static let significantXP = 20
    private static let significantStatChange = 15
    private static let hungryThreshold = 70.0
    private static let stepInterval = 1_000

    static func activities(
        from snapshots: [PetSnapshot],
        calendar: Calendar = .current
    ) -> [PetActivity] {
        guard snapshots.count >= 2 else { return [] }

        var result: [PetActivity] = []
        for (previous, current) in zip(snapshots, snapshots.dropFirst()) {
            let kinds = changes(from: previous, to: current, calendar: calendar)
            result.append(contentsOf: kinds.enumerated().map { index, kind in
                PetActivity(
                    id: "\(current.version)-\(index)",
                    date: current.timestamp,
                    kind: kind
                )
            })
        }
        return result.reversed()
    }

    private static func changes(
        from previous: PetSnapshot,
        to current: PetSnapshot,
        calendar: Calendar
    ) -> [PetActivityKind] {
        var changes: [PetActivityKind] = []

        if current.level > previous.level {
            changes.append(.levelIncreased(to: current.level))
        }

        let xpDifference = current.xp - previous.xp
        if xpDifference >= significantXP {
            changes.append(.xpIncreased(by: xpDifference))
        }

        if previous.hunger < hungryThreshold,
           current.hunger >= hungryThreshold {
            changes.append(.becameHungry)
        } else if previous.hunger >= hungryThreshold,
                  current.hunger < hungryThreshold {
            changes.append(.recoveredFromHunger)
        }

        appendSignificantChange(
            current.happiness - previous.happiness,
            as: { .happinessChanged(by: $0) },
            to: &changes
        )
        appendSignificantChange(
            current.energy - previous.energy,
            as: { .energyChanged(by: $0) },
            to: &changes
        )

        if calendar.isDate(previous.timestamp, inSameDayAs: current.timestamp),
           let previousSteps = previous.todayStepCount,
           let currentSteps = current.todayStepCount,
           currentSteps > previousSteps {
            let previousMilestone = previousSteps / stepInterval
            let currentMilestone = currentSteps / stepInterval
            if currentMilestone > previousMilestone {
                changes.append(.stepMilestone(currentMilestone * stepInterval))
            }
        }

        return changes
    }

    private static func appendSignificantChange(
        _ difference: Double,
        as makeKind: (Int) -> PetActivityKind,
        to changes: inout [PetActivityKind]
    ) {
        let roundedDifference = Int(difference.rounded())
        guard abs(roundedDifference) >= significantStatChange else { return }
        changes.append(makeKind(roundedDifference))
    }
}

struct PetStatTrend: Equatable {
    let hunger: Int
    let happiness: Int
    let energy: Int

    static func derive(from snapshots: [PetSnapshot]) -> PetStatTrend? {
        guard let first = snapshots.first, let last = snapshots.last,
              first.version != last.version else { return nil }

        let trend = PetStatTrend(
            hunger: Int((last.hunger - first.hunger).rounded()),
            happiness: Int((last.happiness - first.happiness).rounded()),
            energy: Int((last.energy - first.energy).rounded())
        )
        guard trend.hunger != 0 || trend.happiness != 0 || trend.energy != 0 else {
            return nil
        }
        return trend
    }
}
