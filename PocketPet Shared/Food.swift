import Foundation

struct Food: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let placeholder: String
    let hungerRestore: Int

    static let samples: [Food] = [
        Food(id: "apple", name: "Apple", placeholder: "🍎", hungerRestore: 12),
        Food(id: "carrot", name: "Carrot", placeholder: "🥕", hungerRestore: 16),
        Food(id: "egg", name: "Egg", placeholder: "🥚", hungerRestore: 20),
        Food(id: "fish", name: "Fish", placeholder: "🐟", hungerRestore: 28),
        Food(id: "treat", name: "Treat", placeholder: "🦴", hungerRestore: 35),
    ]

    static func food(withID id: String) -> Food? {
        samples.first { $0.id == id }
    }
}
