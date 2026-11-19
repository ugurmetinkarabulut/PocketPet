struct PetSpecies: Equatable {
    let assetNamePrefix: String

    static let defaultPet = PetSpecies(assetNamePrefix: "pet_default")

    func assetName(for state: PetVisualState) -> String {
        switch state {
        case .idle:
            return "\(assetNamePrefix)_idle"
        case .happy:
            return "\(assetNamePrefix)_happy"
        case .hungry:
            return "\(assetNamePrefix)_hungry"
        case .sleepy:
            return "\(assetNamePrefix)_sleepy"
        case .eating:
            return "\(assetNamePrefix)_eating"
        case .playing:
            return "\(assetNamePrefix)_playing"
        }
    }
}
