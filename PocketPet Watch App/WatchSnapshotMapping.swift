import Foundation

extension PetSnapshot {
    init(state: PetState, todayStepCount: Int?, timestamp: Date = .now) {
        self.init(
            version: max(1, Int64(timestamp.timeIntervalSince1970 * 1_000)),
            timestamp: timestamp,
            petName: state.name,
            hunger: state.hunger,
            happiness: state.happiness,
            energy: state.energy,
            xp: state.xp,
            level: state.level,
            visualState: state.visualState.rawValue,
            todayStepCount: todayStepCount
        )
    }
}
