import SwiftUI

struct OnboardingView: View {
    let store: PetStateStore

    @State private var step = OnboardingStep.welcome
    @State private var petName = ""

    var body: some View {
        ViewThatFits(in: .vertical) {
            content(compact: false)

            ScrollView {
                content(compact: true)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func content(compact: Bool) -> some View {
        VStack(spacing: compact ? 7 : 10) {
            switch step {
            case .welcome:
                WelcomeOnboardingScreen(compact: compact)
            case .care:
                CareOnboardingScreen(compact: compact)
            case .name:
                PetNameOnboardingScreen(
                    petName: $petName,
                    compact: compact
                )
            }

            Button(buttonTitle, action: advance)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity, minHeight: 44)
                .disabled(step == .name && validatedPetName == nil)
                .accessibilityHint(buttonHint)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 6)
    }

    private var validatedPetName: String? {
        PetNameRules.validatedName(petName)
    }

    private var buttonTitle: String {
        step == .name ? "Start" : "Continue"
    }

    private var buttonHint: String {
        step == .name ? "Saves your pet's name" : "Shows the next introduction"
    }

    private func advance() {
        switch step {
        case .welcome:
            step = .care
        case .care:
            step = .name
        case .name:
            guard let validatedPetName else { return }
            store.completeOnboarding(petName: validatedPetName)
        }
    }
}

private enum OnboardingStep {
    case welcome
    case care
    case name
}

private struct WelcomeOnboardingScreen: View {
    let compact: Bool

    var body: some View {
        content(petHeight: compact ? 68 : 88)
            .accessibilityElement(children: .combine)
    }

    private func content(petHeight: CGFloat) -> some View {
        VStack(spacing: 5) {
            PetVisualView(state: .happy)
                .frame(height: petHeight)

            Text("Welcome to PocketPet")
                .font(.headline)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.85)

            Text("A tiny friend for your wrist.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct CareOnboardingScreen: View {
    let compact: Bool

    var body: some View {
        content(petHeight: compact ? 56 : 76)
            .accessibilityElement(children: .combine)
    }

    private func content(petHeight: CGFloat) -> some View {
        VStack(spacing: 6) {
            PetVisualView(state: .playing)
                .frame(height: petHeight)

            Text("Care & Grow")
                .font(.headline)

            Text("Feed, play, and walk together.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

private struct PetNameOnboardingScreen: View {
    @Binding var petName: String
    let compact: Bool

    var body: some View {
        content(petHeight: compact ? 48 : 64)
    }

    private func content(petHeight: CGFloat) -> some View {
        VStack(spacing: 7) {
            PetVisualView(state: .idle)
                .frame(height: petHeight)

            Text("Name Your Pet")
                .font(.headline)

            TextField("Pet name", text: $petName)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onChange(of: petName) { _, newName in
                    let limitedName = PetNameRules.limitedName(newName)
                    if limitedName != newName {
                        petName = limitedName
                    }
                }
                .accessibilityHint(
                    "Up to \(PetNameRules.characterLimit) characters"
                )

            HStack {
                if !petName.isEmpty,
                   PetNameRules.validatedName(petName) == nil {
                    Text("Enter a name")
                        .foregroundStyle(.orange)
                }

                Spacer()

                Text("\(petName.count)/\(PetNameRules.characterLimit)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.caption2)
        }
    }
}

#Preview("Onboarding") {
    OnboardingView(
        store: PetStateStore(
            persistence: PreviewPetStatePersistence(
                onboardingCompleted: false
            )
        )
    )
}
