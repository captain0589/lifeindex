import SwiftUI

@main
struct LifeIndexApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                MainTabView()
                    .environmentObject(healthKitManager)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(healthKitManager)
            }
        }
    }
}
