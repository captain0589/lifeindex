import SwiftUI

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared

    @State private var lastScrollOffset: CGFloat = 0
    @State private var tabBarHidden = false

    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("tab.home".localized, systemImage: "house.fill", value: 0) {
                DashboardView(viewModel: dashboardViewModel, selectedTab: $selectedTab)
                    .scrollTracker(tab: 0, selectedTab: selectedTab, onOffsetChange: handleScroll)
            }
            Tab("tab.sleep".localized, systemImage: "moon.zzz.fill", value: 1) {
                SleepTabView()
                    .scrollTracker(tab: 1, selectedTab: selectedTab, onOffsetChange: handleScroll)
            }
            Tab("tab.fitness".localized, systemImage: "figure.run", value: 2) {
                FitnessView()
                    .scrollTracker(tab: 2, selectedTab: selectedTab, onOffsetChange: handleScroll)
            }
            Tab("tab.calories".localized, systemImage: "fork.knife", value: 3) {
                FoodView()
                    .scrollTracker(tab: 3, selectedTab: selectedTab, onOffsetChange: handleScroll)
            }
            Tab("tab.mood".localized, systemImage: "book.closed.fill", value: 4) {
                WellnessView()
                    .scrollTracker(tab: 4, selectedTab: selectedTab, onOffsetChange: handleScroll)
            }
        }
        .toolbarVisibility(tabBarHidden ? .hidden : .visible, for: .tabBar)
        .onChange(of: selectedTab) { _, _ in
            hapticFeedback.impactOccurred()
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                tabBarHidden = false
            }
            lastScrollOffset = 0
        }
        .preferredColorScheme(appearanceManager.preferredColorScheme)
        .id(languageManager.currentLanguage)
    }

    private func handleScroll(offset: CGFloat) {
        let delta = offset - lastScrollOffset
        lastScrollOffset = offset

        withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
            if delta < -6 && offset < -40 {
                tabBarHidden = true
            }
            if delta > 6 {
                tabBarHidden = false
            }
        }
    }
}

// MARK: - Scroll tracker modifier

private struct ScrollTrackerModifier: ViewModifier {
    let tab: Int
    let selectedTab: Int
    let onOffsetChange: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: ScrollOffsetKey.self,
                            value: geo.frame(in: .global).minY
                        )
                }
            )
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                guard tab == selectedTab else { return }
                onOffsetChange(value)
            }
    }
}

extension View {
    func scrollTracker(tab: Int, selectedTab: Int, onOffsetChange: @escaping (CGFloat) -> Void) -> some View {
        modifier(ScrollTrackerModifier(tab: tab, selectedTab: selectedTab, onOffsetChange: onOffsetChange))
    }
}
