import SwiftUI

struct SettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @State private var notificationsEnabled = true
    @State private var dailyReminderTime = Date()

    var body: some View {
        NavigationStack {
            List {
                Section("Health Data") {
                    NavigationLink {
                        Text("Health data sources")
                    } label: {
                        Label("Connected Sources", systemImage: "heart.circle")
                    }

                    Button {
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Apple Health", systemImage: "heart.text.clipboard")
                    }
                }

                Section("Notifications") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Daily Reminder", systemImage: "bell")
                    }

                    if notificationsEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: $dailyReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Theme.secondaryText)
                    }

                    NavigationLink {
                        Text("Privacy Policy")
                    } label: {
                        Label("Privacy Policy", systemImage: "lock.shield")
                    }
                }

                Section("Debug") {
                    Button("Reset Onboarding") {
                        hasCompletedOnboarding = false
                    }
                    .foregroundStyle(.red)
                }
            }
            .navigationTitle("Settings")
        }
    }
}
