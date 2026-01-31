import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var dashboardViewModel = DashboardViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                DashboardView(viewModel: dashboardViewModel)
            }

            Tab("Calories", systemImage: "fork.knife", value: 1) {
                FoodView()
            }

            Tab("Fitness", systemImage: "figure.run", value: 2) {
                FitnessView()
            }

            Tab("Wellness", systemImage: "heart.fill", value: 3) {
                WellnessView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: 4) {
                SettingsView()
            }
        }
    }
}
