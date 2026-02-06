import SwiftUI
import Combine

// MARK: - App Color Scheme Manager

final class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    @Published var colorSchemePreference: Int = UserDefaults.standard.integer(forKey: "appColorScheme") {
        didSet {
            UserDefaults.standard.set(colorSchemePreference, forKey: "appColorScheme")
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch colorSchemePreference {
        case 1: return .light
        case 2: return .dark
        default: return nil // system
        }
    }

    private init() {}
}

// MARK: - Theme

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
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    // MARK: - Font Sizes (for custom sizes not in system)
    enum FontSize {
        static let tiny: CGFloat = 9
        static let small: CGFloat = 11
        static let caption2: CGFloat = 12
        static let caption: CGFloat = 14
        static let body: CGFloat = 16
        static let title3: CGFloat = 20
        static let title2: CGFloat = 24
        static let title: CGFloat = 28
        static let largeTitle: CGFloat = 34
        static let display: CGFloat = 40
        static let hero: CGFloat = 48
        static let giant: CGFloat = 56
        static let massive: CGFloat = 64
        static let colossal: CGFloat = 80
    }

    // MARK: - Icon Sizes
    enum IconSize {
        static let xs: CGFloat = 10
        static let sm: CGFloat = 14
        static let md: CGFloat = 18
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 40
    }

    // MARK: - Icon Frame Sizes
    enum IconFrame {
        static let sm: CGFloat = 20
        static let md: CGFloat = 28
        static let lg: CGFloat = 36
        static let xl: CGFloat = 44
        static let xxl: CGFloat = 56
    }

    // MARK: - Corner Radius
    enum CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let full: CGFloat = 9999 // For pill shapes
    }

    // MARK: - Component Sizes
    enum ComponentSize {
        static let buttonHeight: CGFloat = 44
        static let buttonHeightLarge: CGFloat = 56
        static let inputHeight: CGFloat = 48
        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 56
        static let avatarLarge: CGFloat = 80
        static let ringSmall: CGFloat = 44
        static let ringMedium: CGFloat = 60
        static let ringLarge: CGFloat = 80
        static let chartHeight: CGFloat = 100
        static let chartHeightLarge: CGFloat = 150
        static let thumbnailSmall: CGFloat = 56
        static let thumbnailMedium: CGFloat = 72
        static let thumbnailLarge: CGFloat = 100
    }

    // MARK: - Progress Bar
    static let progressBarHeight: CGFloat = 8

    // MARK: - Colors (adaptive for dark/light mode)
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let tertiaryText = Color(uiColor: .tertiaryLabel)
    static let background = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)
    static let groupedBackground = Color(.systemGroupedBackground)
    static let separator = Color(.separator)

    // Metric-specific colors (these auto-adapt slightly in dark mode)
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

    // Additional semantic colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue

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

    // Dark mode header gradient (rich jewel tones, more vibrant for better visibility)
    static let headerGradientDark = LinearGradient(
        colors: [
            Color(red: 0.35, green: 0.25, blue: 0.50), // rich purple
            Color(red: 0.28, green: 0.22, blue: 0.48), // deep indigo
            Color(red: 0.20, green: 0.18, blue: 0.38), // dark navy
            Color(red: 0.12, green: 0.12, blue: 0.25)  // midnight blue
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Dynamic header gradient based on color scheme
    static func headerGradient(for colorScheme: ColorScheme) -> LinearGradient {
        colorScheme == .dark ? headerGradientDark : headerGradient
    }

    // MARK: - Fonts
    static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let title = Font.system(.title2, design: .rounded, weight: .semibold)
    static let title3 = Font.system(.title3, design: .rounded, weight: .semibold)
    static let headline = Font.system(.headline, design: .rounded, weight: .medium)
    static let subheadline = Font.system(.subheadline, design: .rounded, weight: .medium)
    static let body = Font.system(.body, design: .rounded)
    static let callout = Font.system(.callout, design: .rounded)
    static let footnote = Font.system(.footnote, design: .rounded)
    static let caption = Font.system(.caption, design: .rounded)
    static let caption2 = Font.system(.caption2, design: .rounded)
    static let scoreFont = Font.system(size: FontSize.giant, weight: .bold, design: .rounded)

    // Custom font helpers
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        Font.system(style, design: .rounded, weight: weight)
    }

    static func rounded(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .rounded)
    }

    // MARK: - Card Style
    static let cardCornerRadius: CGFloat = CornerRadius.lg
    static let cardPadding: CGFloat = Spacing.lg
    static let cardShadowRadius: CGFloat = 4

    // MARK: - Shadows
    enum Shadow {
        static let small = (color: Color.black.opacity(0.04), radius: CGFloat(4), y: CGFloat(2))
        static let medium = (color: Color.black.opacity(0.06), radius: CGFloat(6), y: CGFloat(3))
        static let large = (color: Color.black.opacity(0.08), radius: CGFloat(10), y: CGFloat(5))
    }
}

// MARK: - View Modifier for Cards

struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(Theme.cardPadding)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous))
            .shadow(color: Theme.Shadow.medium.color, radius: Theme.Shadow.medium.radius, y: Theme.Shadow.medium.y)
    }
}

// MARK: - Page Background Modifier

struct PageBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var showGradient: Bool = true
    var gradientHeight: CGFloat = 380

    func body(content: Content) -> some View {
        content
            .background {
                if showGradient {
                    ZStack {
                        Theme.background.ignoresSafeArea()
                        VStack {
                            Theme.headerGradient(for: colorScheme)
                                .frame(height: gradientHeight)
                                .mask(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            Spacer()
                        }
                        .ignoresSafeArea()
                    }
                } else {
                    Theme.background.ignoresSafeArea()
                }
            }
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func pageBackground(showGradient: Bool = true, gradientHeight: CGFloat = 380) -> some View {
        modifier(PageBackground(showGradient: showGradient, gradientHeight: gradientHeight))
    }
}
