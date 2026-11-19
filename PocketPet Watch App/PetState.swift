import Foundation

enum PetDecayConstants {
    static let hungerPerHour = 4.0
    static let happinessPerHour = 2.0
    static let energyPerHour = 3.0
    static let maximumElapsedInterval: TimeInterval = 60 * 60 * 24 * 30
}

struct PetState: Codable, Equatable {
    var name: String
    var hunger: Double
    var happiness: Double
    var energy: Double
    var xp: Int
    private(set) var level: Int
    var lastUpdated: Date
    var rewardedStepDate: Date?
    var rewardedSteps: Int?

    static let initial = PetState(
        name: "Mochi",
        hunger: 22,
        happiness: 78,
        energy: 72,
        xp: 0,
        level: 1,
        lastUpdated: .now,
        rewardedStepDate: nil,
        rewardedSteps: nil
    )

    var visualState: PetVisualState {
        if hunger >= 70 { return .hungry }
        if energy <= 30 { return .sleepy }
        if happiness >= 75 { return .happy }
        return .idle
    }

    var status: PetStatus {
        let needs: [(status: PetStatus, severity: Double)] = [
            (.hungry, hunger),
            (.sleepy, 100 - energy),
            (.lonely, 100 - happiness),
        ]
        let primaryNeed = needs.max { $0.severity < $1.severity }

        if let primaryNeed, primaryNeed.severity >= 70 {
            return primaryNeed.status
        }
        return happiness >= 75 ? .happy : .content
    }

    var statusSeverity: Double {
        switch status {
        case .hungry:
            return hunger
        case .lonely:
            return 100 - happiness
        case .sleepy:
            return 100 - energy
        case .content, .happy:
            return 0
        }
    }

    mutating func applyDecay(at date: Date) {
        let elapsed = date.timeIntervalSince(lastUpdated)
        guard elapsed.isFinite, elapsed > 0 else {
            lastUpdated = date
            return
        }

        let elapsedHours = min(
            elapsed,
            PetDecayConstants.maximumElapsedInterval
        ) / 3_600
        hunger += elapsedHours * PetDecayConstants.hungerPerHour
        happiness -= elapsedHours * PetDecayConstants.happinessPerHour
        energy -= elapsedHours * PetDecayConstants.energyPerHour
        lastUpdated = date
        clampStats()
    }

    func decayed(at date: Date) -> PetState {
        var currentState = self
        currentState.applyDecay(at: date)
        return currentState
    }

    mutating func clampStats() {
        hunger = hunger.clamped(to: 0...100)
        happiness = happiness.clamped(to: 0...100)
        energy = energy.clamped(to: 0...100)
    }

    mutating func grantXP(_ amount: Int) {
        xp = max(0, xp + amount)
        level = max(1, (xp / PetProgression.xpPerLevel) + 1)
    }

    private enum PetProgression {
        static let xpPerLevel = 100
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
