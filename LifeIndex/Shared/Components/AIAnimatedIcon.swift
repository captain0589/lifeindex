import SwiftUI
import Lottie

// MARK: - LottieView (UIViewRepresentable bridge)

struct LottieView: UIViewRepresentable {
    let animationName: String
    var loopMode: LottieLoopMode = .loop
    var contentMode: UIView.ContentMode = .scaleAspectFit
    var animationSpeed: CGFloat = 1.0
    @Binding var isPlaying: Bool

    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(name: animationName)
        animationView.loopMode = loopMode
        animationView.contentMode = contentMode
        animationView.animationSpeed = animationSpeed
        animationView.backgroundBehavior = .pauseAndRestore
        // Prevent the UIKit intrinsic size (700×700) from overriding SwiftUI's .frame()
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        animationView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        if isPlaying {
            animationView.play()
        }
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.animationSpeed = animationSpeed
        if isPlaying {
            if !uiView.isAnimationPlaying {
                uiView.play()
            }
        } else {
            uiView.pause()
        }
    }
}

// MARK: - AI Animated Icon (wraps Lottie JSON)
struct AIAnimatedIcon: View {
    var size: CGFloat = 56
    var isAnimating: Bool = true
    // The JSON canvas has ~45% whitespace margin; overscale to fill it
    private let overscale: CGFloat = 1.85

    var body: some View {
        LottieView(
            animationName: "AI-Evaluation-Loading",
            loopMode: .loop,
            contentMode: .scaleAspectFit,
            animationSpeed: 1.0,
            isPlaying: .constant(isAnimating)
        )
        .frame(width: size * overscale, height: size * overscale)
        .frame(width: size, height: size)
        .clipShape(Circle())
        .allowsHitTesting(false)
    }
}

// MARK: - Floating Chat Button (uses AIAnimatedIcon)

struct FloatingChatButton: View {
    @Binding var showChat: Bool

    var body: some View {
        Button {
            showChat = true
        } label: {
            VStack(alignment: .center, spacing: 6) {
                // Label above the button
                Text("chat.withAI".localized)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())

                ZStack {
                    // Background circle
                    Circle()
                        .fill(Color(.systemGray6))
                        .frame(width: 56, height: 56)
                        .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 6)

                    // Lottie icon
                    AIAnimatedIcon(size: 56)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Small AI Avatar (for chat bubbles)

struct AIAvatarIcon: View {
    var size: CGFloat = 32

    var body: some View {
        // No background circle — just the raw Lottie, no extra padding
        AIAnimatedIcon(size: size)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack(spacing: 40) {
            AIAnimatedIcon(size: 80)
            AIAnimatedIcon(size: 56)
            AIAvatarIcon(size: 32)
            FloatingChatButton(showChat: .constant(false))
        }
    }
}
