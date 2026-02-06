import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("tab.home".localized, systemImage: "house.fill", value: 0) {
                DashboardView(viewModel: dashboardViewModel)
            }

            Tab("tab.sleep".localized, systemImage: "moon.zzz.fill", value: 1) {
                SleepTabView()
            }

            Tab("food.title".localized, systemImage: "fork.knife", value: 2) {
                FoodView()
            }

            Tab("tab.fitness".localized, systemImage: "figure.run", value: 3) {
                FitnessView()
            }

            Tab("tab.mood".localized, systemImage: "face.smiling.fill", value: 4) {
                WellnessView()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            hapticFeedback.impactOccurred()
        }
        .preferredColorScheme(appearanceManager.preferredColorScheme)
        .id(languageManager.currentLanguage)
    }
}
