import SwiftUI

enum Theme {
    static let accentColor = Color.blue

    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: - Icon Sizes
    enum IconSize {
        static let sm: CGFloat = 14
        static let md: CGFloat = 18
        static let lg: CGFloat = 24
    }

    // MARK: - Icon Frame Sizes
    enum IconFrame {
        static let sm: CGFloat = 20
        static let md: CGFloat = 28
        static let lg: CGFloat = 36
    }

    // MARK: - Progress Bar
    static let progressBarHeight: CGFloat = 8

    // MARK: - Colors
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)

    // Metric-specific colors
    static let heartRate = Color.red
    static let steps = Color.green
    static let sleep = Color.indigo
    static let calories = Color.orange
    static let hrv = Color.cyan
    static let bloodOxygen = Color.blue
    static let activity = Color.pink
    static let mindfulness = Color.purple
    static let mood = Color.yellow
    static let recovery = Color.mint

    // Score gradient
    static let scoreGradient = LinearGradient(
        colors: [Color.red, Color.orange, Color.yellow, Color.green, Color.mint],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Header gradient (Apple Health-inspired warm gradient)
    static let headerGradient = LinearGradient(
        colors: [
            Color(red: 0.92, green: 0.55, blue: 0.42), // deeper peach
            Color(red: 0.82, green: 0.42, blue: 0.52), // deeper salmon
            Color(red: 0.62, green: 0.38, blue: 0.72), // deeper purple
            Color(red: 0.45, green: 0.35, blue: 0.68)  // rich violet
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Fonts
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title2, design: .rounded, weight: .semibold)
    static let headline = Font.system(.headline, design: .rounded, weight: .medium)
    static let body = Font.system(.body, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let scoreFont = Font.system(size: 56, weight: .bold, design: .rounded)

    // MARK: - Card Style
    static let cardCornerRadius: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let cardShadowRadius: CGFloat = 4
}

// MARK: - View Modifier for Cards
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
