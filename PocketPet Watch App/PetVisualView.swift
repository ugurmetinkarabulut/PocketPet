import SwiftUI
import UIKit

struct PetVisualView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let state: PetVisualState
    let species: PetSpecies

    @State private var isAnimating = false

    init(state: PetVisualState, species: PetSpecies = .defaultPet) {
        self.state = state
        self.species = species
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                appearance.tint.opacity(0.34),
                                appearance.tint.opacity(0.06),
                            ],
                            center: .center,
                            startRadius: size * 0.08,
                            endRadius: size * 0.58
                        )
                    )
                    .frame(width: size, height: size)

                artwork(size: size * 0.82)
                    .scaleEffect(animatedScale)
                    .offset(y: animatedOffset)
                    .shadow(
                        color: appearance.tint.opacity(0.25),
                        radius: size * 0.07,
                        y: size * 0.035
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .onAppear { restartAnimation() }
        .onChange(of: state) {
            restartAnimation()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pet is \(appearance.accessibilityDescription)")
    }

    private var animatedScale: CGFloat {
        reduceMotion || !isAnimating ? 1 : appearance.scale
    }

    private var animatedOffset: CGFloat {
        reduceMotion || !isAnimating ? 0 : appearance.offset
    }

    @ViewBuilder
    private func artwork(size: CGFloat) -> some View {
        if let image = UIImage(named: species.assetName(for: state)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(state.placeholder)
                .font(.system(size: size * 0.7))
        }
    }

    private func restartAnimation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isAnimating = false
        }

        guard !reduceMotion else { return }
        withAnimation(appearance.animation) {
            isAnimating = true
        }
    }

    private var appearance: Appearance {
        switch state {
        case .idle:
            Appearance(
                .mint,
                1.03,
                -2,
                "resting",
                .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
            )
        case .happy:
            Appearance(
                .pink,
                1.08,
                -4,
                "happy",
                .spring(duration: 0.45, bounce: 0.35)
                    .repeatCount(2, autoreverses: true)
            )
        case .hungry:
            Appearance(
                .orange,
                0.97,
                1,
                "hungry",
                .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
            )
        case .sleepy:
            Appearance(
                .indigo,
                0.96,
                2,
                "sleepy",
                .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
            )
        case .eating:
            Appearance(
                .orange,
                1.06,
                -2,
                "eating",
                .easeInOut(duration: 0.25).repeatForever(autoreverses: true)
            )
        case .playing:
            Appearance(
                .cyan,
                1.08,
                -6,
                "playing",
                .spring(duration: 0.38, bounce: 0.45)
                    .repeatCount(3, autoreverses: true)
            )
        }
    }
}

private struct Appearance {
    let tint: Color
    let scale: CGFloat
    let offset: CGFloat
    let accessibilityDescription: String
    let animation: Animation

    init(
        _ tint: Color,
        _ scale: CGFloat,
        _ offset: CGFloat,
        _ accessibilityDescription: String,
        _ animation: Animation
    ) {
        self.tint = tint
        self.scale = scale
        self.offset = offset
        self.accessibilityDescription = accessibilityDescription
        self.animation = animation
    }
}

#Preview("Pet States") {
    ScrollView(.horizontal) {
        HStack {
            ForEach(PetVisualState.allCases, id: \.self) { state in
                PetVisualView(state: state)
                    .frame(width: 120, height: 110)
            }
        }
    }
}
