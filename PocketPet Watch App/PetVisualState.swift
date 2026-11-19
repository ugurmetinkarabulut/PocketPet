enum PetVisualState: String, CaseIterable, Hashable {
    case idle
    case happy
    case hungry
    case sleepy
    case eating
    case playing

    var placeholder: String {
        switch self {
        case .idle, .happy, .eating, .playing:
            return "🐶"
        case .hungry:
            return "🥺"
        case .sleepy:
            return "😴"
        }
    }
}

enum PetStatus: Equatable {
    case content
    case happy
    case hungry
    case lonely
    case sleepy

    var shortLabel: String {
        switch self {
        case .content:
            return "Doing well"
        case .happy:
            return "Happy"
        case .hungry:
            return "Hungry"
        case .lonely:
            return "Needs love"
        case .sleepy:
            return "Sleepy"
        }
    }

    var symbolName: String {
        switch self {
        case .content:
            return "checkmark"
        case .happy:
            return "heart.fill"
        case .hungry:
            return "fork.knife"
        case .lonely:
            return "heart.slash"
        case .sleepy:
            return "moon.zzz.fill"
        }
    }
}
