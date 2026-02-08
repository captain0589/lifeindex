import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var languageManager = LanguageManager.shared
    @Binding var hasCompletedOnboarding: Bool

    @State private var currentPage = 0
    @State private var isRequestingPermission = false
    @State private var showError = false
    @State private var errorMessage = ""

    private let totalPages = 5

    var body: some View {
        ZStack {
            // Background
            Theme.background
                .ignoresSafeArea()

            // Gradient overlay
            LinearGradient(
                colors: [
                    Theme.accentColor.opacity(0.15),
                    Theme.accentColor.opacity(0.05),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 400)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Content
                TabView(selection: $currentPage) {
                    // Page 0: Language Selection
                    LanguageSelectionPage(languageManager: languageManager)
                        .tag(0)

                    // Page 1: Welcome
                    WelcomePage()
                        .tag(1)

                    // Page 2: Features
                    FeaturesPage()
                        .tag(2)

                    // Page 3: Privacy
                    PrivacyPage()
                        .tag(3)

                    // Page 4: Health Access
                    HealthAccessPage(
                        isRequestingPermission: $isRequestingPermission,
                        hasCompletedOnboarding: $hasCompletedOnboarding,
                        requestHealthAccess: requestHealthAccess
                    )
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Custom page indicator and navigation
                VStack(spacing: Theme.Spacing.lg) {
                    // Page dots
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { index in
                            Circle()
                                .fill(currentPage == index ? Theme.accentColor : Theme.secondaryText.opacity(0.3))
                                .frame(width: currentPage == index ? 10 : 8, height: currentPage == index ? 10 : 8)
                                .animation(.easeInOut(duration: 0.2), value: currentPage)
                        }
                    }
                    .padding(.top, Theme.Spacing.md)

                    // Navigation buttons
                    if currentPage < totalPages - 1 {
                        HStack(spacing: Theme.Spacing.lg) {
                            if currentPage > 0 {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        currentPage -= 1
                                    }
                                } label: {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: "chevron.left")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("common.back".localized)
                                    }
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .foregroundStyle(Theme.secondaryText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(.regularMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }

                            Button {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    currentPage += 1
                                }
                            } label: {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Text("common.next".localized)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Theme.accentColor)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, Theme.Spacing.xl)
                    }
                }
                .padding(.bottom, Theme.Spacing.xxl)
            }
        }
        .alert("common.error".localized, isPresented: $showError) {
            Button("common.ok".localized) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func requestHealthAccess() {
        isRequestingPermission = true
        Task {
            do {
                try await healthKitManager.requestAuthorization()
                hasCompletedOnboarding = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isRequestingPermission = false
        }
    }
}

// MARK: - Language Selection Page

private struct LanguageSelectionPage: View {
    @ObservedObject var languageManager: LanguageManager
    @State private var selectedLanguage: AppLanguage = .english

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Icon with background
            ZStack {
                Circle()
                    .fill(Theme.accentColor.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "globe")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(Theme.accentColor)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("onboarding.selectLanguage".localized)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("onboarding.selectLanguageDesc".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // Language options
            VStack(spacing: Theme.Spacing.md) {
                ForEach(AppLanguage.allCases) { language in
                    LanguageOptionButton(
                        language: language,
                        isSelected: selectedLanguage == language,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedLanguage = language
                                languageManager.setLanguage(language)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.md)

            Spacer()
            Spacer()
        }
        .onAppear {
            selectedLanguage = languageManager.currentLanguage
        }
    }
}

// MARK: - Language Option Button

private struct LanguageOptionButton: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Text(language.flag)
                    .font(.system(size: 28))

                Text(language.displayName)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Theme.accentColor)
                } else {
                    Circle()
                        .strokeBorder(Theme.secondaryText.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(Theme.Spacing.lg)
            .background {
                if isSelected {
                    Theme.accentColor.opacity(0.1)
                } else {
                    Rectangle().fill(.regularMaterial)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Welcome Page

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // App icon style
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.accentColor, Theme.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: "heart.text.clipboard.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(.white)
            }
            .shadow(color: Theme.accentColor.opacity(0.3), radius: 20, y: 10)

            VStack(spacing: Theme.Spacing.sm) {
                Text("onboarding.welcome".localized)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("onboarding.welcomeSubtitle".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // Score preview
            VStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .stroke(Theme.accentColor.opacity(0.2), lineWidth: 10)
                        .frame(width: 100, height: 100)

                    Circle()
                        .trim(from: 0, to: 0.78)
                        .stroke(
                            LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .frame(width: 100, height: 100)
                        .rotationEffect(.degrees(-90))

                    Text("78")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                }

                Text("onboarding.yourScore".localized)
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.top, Theme.Spacing.lg)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Features Page

private struct FeaturesPage: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("onboarding.trackEverything".localized)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("onboarding.trackEverythingDesc".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // Features grid
            VStack(spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.md) {
                    FeatureCard(icon: "chart.pie.fill", color: Theme.accentColor, title: "onboarding.features.lifeindex".localized)
                    FeatureCard(icon: "moon.zzz.fill", color: Theme.sleep, title: "onboarding.features.sleep".localized)
                }
                HStack(spacing: Theme.Spacing.md) {
                    FeatureCard(icon: "flame.fill", color: Theme.calories, title: "onboarding.features.calories".localized)
                    FeatureCard(icon: "face.smiling.fill", color: .purple, title: "onboarding.features.mood".localized)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)

            Spacer()
            Spacer()
        }
    }
}

private struct FeatureCard: View {
    let icon: String
    let color: Color
    let title: String

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(color)

            Text(title)
                .font(.system(.caption, design: .rounded, weight: .medium))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Spacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Privacy Page

private struct PrivacyPage: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50, weight: .medium))
                    .foregroundStyle(.green)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("onboarding.privacy".localized)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("onboarding.privacyDesc".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // Privacy features
            VStack(spacing: Theme.Spacing.md) {
                PrivacyFeatureRow(icon: "iphone", text: "onboarding.privacy.onDevice".localized)
                PrivacyFeatureRow(icon: "hand.raised.fill", text: "onboarding.privacy.noSelling".localized)
                PrivacyFeatureRow(icon: "apple.logo", text: "onboarding.privacy.appleHealth".localized)
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.top, Theme.Spacing.md)

            Spacer()
            Spacer()
        }
    }
}

private struct PrivacyFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 44, height: 44)
                .background(.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(text)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.primaryText)

            Spacer()

            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.green)
        }
        .padding(Theme.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Health Access Page

private struct HealthAccessPage: View {
    @Binding var isRequestingPermission: Bool
    @Binding var hasCompletedOnboarding: Bool
    let requestHealthAccess: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 120, height: 120)

                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 60, weight: .medium))
                    .foregroundStyle(.red)
            }

            VStack(spacing: Theme.Spacing.sm) {
                Text("onboarding.healthPermission".localized)
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("onboarding.healthPermissionDesc".localized)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Theme.Spacing.xl)

            // Health data icons
            HStack(spacing: Theme.Spacing.lg) {
                HealthDataIcon(icon: "heart.fill", color: .red)
                HealthDataIcon(icon: "figure.walk", color: .green)
                HealthDataIcon(icon: "moon.zzz.fill", color: Theme.sleep)
                HealthDataIcon(icon: "flame.fill", color: .orange)
            }
            .padding(.top, Theme.Spacing.md)

            Spacer()

            // Buttons
            VStack(spacing: Theme.Spacing.md) {
                Button {
                    requestHealthAccess()
                } label: {
                    if isRequestingPermission {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                    } else {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 18, weight: .semibold))
                            Text("onboarding.allowAccess".localized)
                                .font(.system(.body, design: .rounded, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                }
                .background(
                    LinearGradient(
                        colors: [.red, .red.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .disabled(isRequestingPermission)

                Button {
                    hasCompletedOnboarding = true
                } label: {
                    Text("onboarding.skip".localized)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }
}

private struct HealthDataIcon: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 24, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 56, height: 56)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
