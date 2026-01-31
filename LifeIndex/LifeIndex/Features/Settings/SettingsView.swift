import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    @AppStorage("dailyCalorieGoal") private var dailyCalorieGoal: Int = 2000
    @AppStorage("profileSyncedFromHealthKit") private var profileSyncedFromHealthKit = false
    @State private var notificationsEnabled = true
    @State private var dailyReminderTime = Date()
    @State private var isSyncing = false

    // Profile
    @AppStorage("userAge") private var userAge: Int = 25
    @AppStorage("userWeightKg") private var userWeightKg: Double = 70
    @AppStorage("userHeightCm") private var userHeightCm: Double = 170
    @AppStorage("userGender") private var userGender: Int = 0
    @AppStorage("userActivityLevel") private var userActivityLevel: Int = 2
    @AppStorage("userGoalType") private var userGoalType: Int = 1

    private var calculatedGoal: Int {
        NutritionEngine.calculateDailyGoal(
            weightKg: userWeightKg,
            heightCm: userHeightCm,
            age: userAge,
            isMale: userGender == 0,
            activityLevel: userActivityLevel,
            goalType: userGoalType
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Label("Age", systemImage: "calendar")
                        Spacer()
                        TextField("Age", value: $userAge, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("years")
                            .foregroundStyle(Theme.secondaryText)
                    }

                    HStack {
                        Label("Weight", systemImage: "scalemass")
                        Spacer()
                        TextField("kg", value: $userWeightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("kg")
                            .foregroundStyle(Theme.secondaryText)
                    }

                    HStack {
                        Label("Height", systemImage: "ruler")
                        Spacer()
                        TextField("cm", value: $userHeightCm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("cm")
                            .foregroundStyle(Theme.secondaryText)
                    }

                    Picker(selection: $userGender) {
                        Text("Male").tag(0)
                        Text("Female").tag(1)
                    } label: {
                        Label("Gender", systemImage: "person")
                    }

                    Picker(selection: $userActivityLevel) {
                        ForEach(NutritionEngine.ActivityLevel.allCases) { level in
                            Text(level.displayName).tag(level.rawValue)
                        }
                    } label: {
                        Label("Activity", systemImage: "figure.walk")
                    }

                    Picker(selection: $userGoalType) {
                        ForEach(NutritionEngine.GoalType.allCases) { goal in
                            Text(goal.displayName).tag(goal.rawValue)
                        }
                    } label: {
                        Label("Goal", systemImage: "target")
                    }
                    Button {
                        Task { await syncFromHealthKit() }
                    } label: {
                        HStack {
                            Label("Sync from Apple Health", systemImage: "heart.fill")
                            Spacer()
                            if isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Recommended daily intake: \(calculatedGoal) kcal based on your profile")
                }

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

                Section("Reports") {
                    NavigationLink {
                        ReportsView()
                    } label: {
                        Label("Health Reports", systemImage: "chart.bar.fill")
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

                    Button("Reset Profile Sync Flag") {
                        profileSyncedFromHealthKit = false
                        debugLog("[LifeIndex] DEBUG: Reset profileSyncedFromHealthKit to false")
                    }
                    .foregroundStyle(.orange)

                    Button("Force Profile Sync Now") {
                        Task { await syncFromHealthKit() }
                    }
                    .foregroundStyle(.blue)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                debugLog("[LifeIndex] Settings .task: profileSyncedFromHealthKit = \(profileSyncedFromHealthKit)")
                if !profileSyncedFromHealthKit {
                    await syncFromHealthKit()
                } else {
                    debugLog("[LifeIndex] Settings: Skipping auto-sync (already synced before)")
                }
            }
        }
    }

    private func syncFromHealthKit() async {
        debugLog("[LifeIndex] ═══ SETTINGS: Starting HealthKit profile sync ═══")
        isSyncing = true

        // Ensure HealthKit is authorized before reading characteristics
        do {
            try await healthKitManager.requestAuthorization()
        } catch {
            debugLog("[LifeIndex] HealthKit auth error for profile sync: \(error)")
            isSyncing = false
            return
        }

        let chars = await healthKitManager.fetchUserCharacteristics()

        debugLog("[LifeIndex] ═══ SETTINGS: Received characteristics ═══")
        debugLog("[LifeIndex]   chars.age = \(chars.age.map(String.init) ?? "nil")")
        debugLog("[LifeIndex]   chars.isMale = \(chars.isMale.map(String.init) ?? "nil")")
        debugLog("[LifeIndex]   chars.heightCm = \(chars.heightCm.map { String(format: "%.1f", $0) } ?? "nil")")
        debugLog("[LifeIndex]   chars.weightKg = \(chars.weightKg.map { String(format: "%.1f", $0) } ?? "nil")")

        var didSync = false
        if let age = chars.age {
            debugLog("[LifeIndex]   → Setting userAge to \(age)")
            userAge = age
            didSync = true
        }
        if let isMale = chars.isMale {
            debugLog("[LifeIndex]   → Setting userGender to \(isMale ? 0 : 1)")
            userGender = isMale ? 0 : 1
            didSync = true
        }
        if let height = chars.heightCm {
            debugLog("[LifeIndex]   → Setting userHeightCm to \(round(height * 10) / 10)")
            userHeightCm = round(height * 10) / 10
            didSync = true
        }
        if let weight = chars.weightKg {
            debugLog("[LifeIndex]   → Setting userWeightKg to \(round(weight * 10) / 10)")
            userWeightKg = round(weight * 10) / 10
            didSync = true
        }

        if didSync {
            profileSyncedFromHealthKit = true
            debugLog("[LifeIndex] ═══ SETTINGS: Sync complete, profileSyncedFromHealthKit = true ═══")
        } else {
            debugLog("[LifeIndex] ═══ SETTINGS: No data synced ═══")
        }
        isSyncing = false
    }
}
