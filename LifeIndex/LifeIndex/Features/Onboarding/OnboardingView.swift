import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @StateObject private var languageManager = LanguageManager.shared
    @Binding var hasCompletedOnboarding: Bool

    @State private var currentPage = 0
    @State private var isRequestingPermission = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                // Page 0: Language Selection
                LanguageSelectionPage(languageManager: languageManager)
                    .tag(0)

                // Page 1: Welcome
                OnboardingPage(
                    icon: "heart.text.clipboard.fill",
                    iconColor: .red,
                    title: "onboarding.welcome".localized,
                    description: "onboarding.welcomeSubtitle".localized
                )
                .tag(1)

                // Page 2: Features
                OnboardingFeaturesPage()
                    .tag(2)

                // Page 3: Privacy
                OnboardingPage(
                    icon: "lock.shield.fill",
                    iconColor: .green,
                    title: "Your Data, Your Device",
                    description: "LifeIndex reads from Apple Health. Your data stays on your device and is never sold."
                )
                .tag(3)

                // Page 4: Health Access
                HealthAccessPage(
                    isRequestingPermission: $isRequestingPermission,
                    hasCompletedOnboarding: $hasCompletedOnboarding,
                    requestHealthAccess: requestHealthAccess
                )
                .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .pageBackground(showGradient: true, gradientHeight: 500)
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

struct LanguageSelectionPage: View {
    @ObservedObject var languageManager: LanguageManager
    @State private var selectedLanguage: AppLanguage = .english

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            // Globe icon
            Image(systemName: "globe")
                .font(.system(size: Theme.FontSize.colossal))
                .foregroundStyle(Theme.accentColor)

            Text("onboarding.selectLanguage".localized)
                .font(Theme.largeTitle)
                .multilineTextAlignment(.center)

            // Language options
            VStack(spacing: Theme.Spacing.md) {
                ForEach(AppLanguage.allCases) { language in
                    LanguageOptionButton(
                        language: language,
                        isSelected: selectedLanguage == language,
                        action: {
                            selectedLanguage = language
                            languageManager.setLanguage(language)
                        }
                    )
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.top, Theme.Spacing.xl)

            Spacer()
            Spacer()
        }
        .onAppear {
            selectedLanguage = languageManager.currentLanguage
        }
    }
}

// MARK: - Language Option Button

struct LanguageOptionButton: View {
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Text(language.flag)
                    .font(.system(size: Theme.FontSize.title))

                Text(language.displayName)
                    .font(Theme.rounded(.title3, weight: .semibold))
                    .foregroundStyle(Theme.primaryText)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: Theme.IconSize.lg))
                        .foregroundStyle(Theme.accentColor)
                } else {
                    Circle()
                        .strokeBorder(Theme.secondaryText.opacity(0.3), lineWidth: 2)
                        .frame(width: Theme.IconSize.lg, height: Theme.IconSize.lg)
                }
            }
            .padding(Theme.Spacing.lg)
            .background(isSelected ? Theme.accentColor.opacity(0.1) : Theme.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: Theme.CornerRadius.md, style: .continuous)
                        .strokeBorder(Theme.accentColor, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Onboarding Features Page

struct OnboardingFeaturesPage: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: Theme.FontSize.colossal))
                .foregroundStyle(.blue)

            Text("Track Everything")
                .font(Theme.largeTitle)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                FeatureRow(icon: "moon.zzz.fill", color: Theme.sleep, text: "onboarding.features.sleep".localized)
                FeatureRow(icon: "figure.run", color: Theme.activity, text: "onboarding.features.activity".localized)
                FeatureRow(icon: "fork.knife", color: Theme.calories, text: "onboarding.features.nutrition".localized)
                FeatureRow(icon: "sparkles", color: Theme.mindfulness, text: "onboarding.features.insights".localized)
            }
            .padding(.horizontal, Theme.Spacing.xxl)

            Spacer()
            Spacer()
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: Theme.IconSize.md))
                .foregroundStyle(color)
                .frame(width: Theme.IconFrame.lg, height: Theme.IconFrame.lg)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))

            Text(text)
                .font(Theme.body)
                .foregroundStyle(Theme.primaryText)
        }
    }
}

// MARK: - Health Access Page

struct HealthAccessPage: View {
    @Binding var isRequestingPermission: Bool
    @Binding var hasCompletedOnboarding: Bool
    let requestHealthAccess: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: Theme.FontSize.colossal))
                .foregroundStyle(.red)

            Text("onboarding.healthPermission".localized)
                .font(Theme.largeTitle)
                .multilineTextAlignment(.center)

            Text("onboarding.healthPermissionDesc".localized)
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)

            Spacer()

            VStack(spacing: Theme.Spacing.md) {
                Button {
                    requestHealthAccess()
                } label: {
                    if isRequestingPermission {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.ComponentSize.buttonHeightLarge)
                    } else {
                        Text("onboarding.allowAccess".localized)
                            .font(Theme.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: Theme.ComponentSize.buttonHeightLarge)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(isRequestingPermission)
                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))

                Button("onboarding.skip".localized) {
                    hasCompletedOnboarding = true
                }
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }
}

// MARK: - Onboarding Page (Generic)

struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: Theme.FontSize.colossal))
                .foregroundStyle(iconColor)

            Text(title)
                .font(Theme.largeTitle)
                .multilineTextAlignment(.center)

            Text(description)
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xxl)

            Spacer()
            Spacer()
        }
    }
}
