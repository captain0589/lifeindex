import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @Binding var hasCompletedOnboarding: Bool

    @State private var currentPage = 0
    @State private var isRequestingPermission = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                OnboardingPage(
                    icon: "heart.text.clipboard.fill",
                    iconColor: .red,
                    title: "Welcome to LifeIndex",
                    description: "Your comprehensive health dashboard that turns raw health data into actionable insights."
                )
                .tag(0)

                OnboardingPage(
                    icon: "chart.xyaxis.line",
                    iconColor: .blue,
                    title: "Track Everything",
                    description: "Sleep, heart rate, activity, recovery, wellness — all unified in one daily score."
                )
                .tag(1)

                OnboardingPage(
                    icon: "lock.shield.fill",
                    iconColor: .green,
                    title: "Your Data, Your Device",
                    description: "LifeIndex reads from Apple Health. Your data stays on your device and is never sold."
                )
                .tag(2)

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "heart.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.red)

                    Text("Connect Apple Health")
                        .font(Theme.largeTitle)
                        .multilineTextAlignment(.center)

                    Text("LifeIndex needs access to your health data to calculate your daily score and show insights.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer()

                    Button {
                        requestHealthAccess()
                    } label: {
                        if isRequestingPermission {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Allow Health Access")
                                .font(Theme.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isRequestingPermission)
                    .padding(.horizontal, 32)

                    Button("Skip for Now") {
                        hasCompletedOnboarding = true
                    }
                    .font(Theme.body)
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.bottom, 32)
                }
                .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") {}
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

struct OnboardingPage: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 80))
                .foregroundStyle(iconColor)

            Text(title)
                .font(Theme.largeTitle)
                .multilineTextAlignment(.center)

            Text(description)
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}
