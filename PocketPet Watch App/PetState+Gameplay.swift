import Foundation

extension PetState {
    mutating func feed(_ food: Food) {
        hunger -= Double(food.hungerRestore)
        happiness += 2
        grantXP(5)
        clampStats()
    }

    mutating func play() {
        happiness += 14
        energy -= 10
        hunger += 5
        grantXP(8)
        clampStats()
    }

    mutating func pet() {
        happiness += 6
        grantXP(2)
        clampStats()
    }

    mutating func rewardXP(
        forTodayStepCount stepCount: Int,
        at date: Date,
        calendar: Calendar = .current
    ) -> Int {
        let safeStepCount = max(0, stepCount)
        let completedSteps = (safeStepCount / PetStepProgression.stepInterval)
            * PetStepProgression.stepInterval
        let isSameRewardDay = rewardedStepDate.map {
            calendar.isDate($0, inSameDayAs: date)
        } ?? false
        let previouslyRewardedSteps = isSameRewardDay ? (rewardedSteps ?? 0) : 0
        let newlyCompletedSteps = max(0, completedSteps - previouslyRewardedSteps)
        let earnedXP = (newlyCompletedSteps / PetStepProgression.stepInterval)
            * PetStepProgression.xpPerInterval

        rewardedStepDate = date
        rewardedSteps = max(previouslyRewardedSteps, completedSteps)

        if earnedXP > 0 {
            grantXP(earnedXP)
        }

        return earnedXP
    }

}

private enum PetStepProgression {
    static let stepInterval = 1_000
    static let xpPerInterval = 2
}
