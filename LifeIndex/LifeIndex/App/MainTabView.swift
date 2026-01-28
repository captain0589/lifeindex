import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var dashboardViewModel = DashboardViewModel()

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                DashboardView(viewModel: dashboardViewModel)
            }

            Tab("Fitness", systemImage: "flame.fill", value: 1) {
                FitnessView()
            }

            Tab("Wellness", systemImage: "heart.fill", value: 2) {
                WellnessView()
            }

            Tab("Reports", systemImage: "chart.bar.fill", value: 3) {
                ReportsView()
            }

            Tab("Settings", systemImage: "gearshape.fill", value: 4) {
                SettingsView()
            }
        }
    }
}
