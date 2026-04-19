import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @ObservedObject private var appearanceManager = AppearanceManager.shared
    @ObservedObject private var languageManager = LanguageManager.shared
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
                // MARK: - Appearance Section
                Section {
                    // Language Picker
                    Picker(selection: Binding(
                        get: { languageManager.currentLanguage },
                        set: { languageManager.setLanguage($0) }
                    )) {
                        ForEach(AppLanguage.allCases) { language in
                            HStack {
                                Text(language.flag)
                                Text(language.displayName)
                            }
                            .tag(language)
                        }
                    } label: {
                        Label("settings.language".localized, systemImage: "globe")
                    }

                    // Color Scheme Picker
                    Picker(selection: $appearanceManager.colorSchemePreference) {
                        Text("settings.systemDefault".localized).tag(0)
                        Text("settings.light".localized).tag(1)
                        Text("settings.dark".localized).tag(2)
                    } label: {
                        Label("settings.colorScheme".localized, systemImage: "circle.lefthalf.filled")
                    }
                } header: {
                    Text("settings.appearance".localized)
                }

                // MARK: - Profile Section
                Section {
                    HStack {
                        Label("settings.age".localized, systemImage: "calendar")
                        Spacer()
                        TextField("settings.age".localized, value: $userAge, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("years")
                            .foregroundStyle(Theme.secondaryText)
                    }

                    HStack {
                        Label("settings.weight".localized, systemImage: "scalemass")
                        Spacer()
                        TextField("units.kg".localized, value: $userWeightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("units.kg".localized)
                            .foregroundStyle(Theme.secondaryText)
                    }

                    HStack {
                        Label("settings.height".localized, systemImage: "ruler")
                        Spacer()
                        TextField("units.cm".localized, value: $userHeightCm, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("units.cm".localized)
                            .foregroundStyle(Theme.secondaryText)
                    }

                    Picker(selection: $userGender) {
                        Text("settings.male".localized).tag(0)
                        Text("settings.female".localized).tag(1)
                    } label: {
                        Label("settings.gender".localized, systemImage: "person")
                    }

                    Picker(selection: $userActivityLevel) {
                        ForEach(NutritionEngine.ActivityLevel.allCases) { level in
                            Text(level.localizedName).tag(level.rawValue)
                        }
                    } label: {
                        Label("settings.activityLevel".localized, systemImage: "figure.walk")
                    }

                    Picker(selection: $userGoalType) {
                        ForEach(NutritionEngine.GoalType.allCases) { goal in
                            Text(goal.localizedName).tag(goal.rawValue)
                        }
                    } label: {
                        Label("settings.goal".localized, systemImage: "target")
                    }

                    Button {
                        Task { await syncFromHealthKit() }
                    } label: {
                        HStack {
                            Label("Sync from Apple Health", systemImage: "heart.fill")
                                .foregroundStyle(Theme.heartRate)
                            Spacer()
                            if isSyncing {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSyncing)
                } header: {
                    Text("settings.profile".localized)
                }

                // MARK: - Health Data Section
                Section("settings.healthData".localized) {
                    NavigationLink {
                        DataConnectionsView()
                    } label: {
                        Label("settings.dataConnections".localized, systemImage: "link.circle")
                    }

                    Button {
                        if let url = URL(string: "x-apple-health://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("settings.openAppleHealth".localized, systemImage: "heart.text.clipboard")
                    }
                }

                // MARK: - Notifications Section
                Section("settings.notifications".localized) {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("settings.dailyReminder".localized, systemImage: "bell")
                    }

                    if notificationsEnabled {
                        DatePicker(
                            "settings.reminderTime".localized,
                            selection: $dailyReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                // MARK: - Reports Section
                Section("reports.title".localized) {
                    NavigationLink {
                        ReportsView()
                    } label: {
                        Label("reports.healthReports".localized, systemImage: "chart.bar.fill")
                    }
                }

                // MARK: - About Section
                Section("settings.about".localized) {
                    HStack {
                        Text("settings.version".localized)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Theme.secondaryText)
                    }

                    NavigationLink {
                        Text("settings.privacyPolicy".localized)
                    } label: {
                        Label("settings.privacyPolicy".localized, systemImage: "lock.shield")
                    }
                }

                // MARK: - Debug Section
                #if DEBUG
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
                #endif
            }
            .navigationTitle("settings.title".localized)
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
        .preferredColorScheme(appearanceManager.preferredColorScheme)
    }

    private func syncFromHealthKit() async {
        debugLog("[LifeIndex] ═══ SETTINGS: Starting HealthKit profile sync ═══")
        isSyncing = true

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

// MARK: - Data Connections View

struct DataConnectionsView: View {
    @State private var isAppleHealthConnected = true
    @State private var isGarminConnected = false

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: Theme.IconSize.lg))
                        .foregroundStyle(.red)
                        .frame(width: Theme.IconFrame.lg)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("settings.appleHealth".localized)
                            .font(Theme.headline)
                        Text(isAppleHealthConnected ? "settings.connected".localized : "settings.notConnected".localized)
                            .font(Theme.caption)
                            .foregroundStyle(isAppleHealthConnected ? Theme.success : Theme.secondaryText)
                    }

                    Spacer()

                    if isAppleHealthConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.success)
                    }
                }
            } footer: {
                Text("Apple Health is the primary data source for LifeIndex")
            }

            Section {
                HStack {
                    Image(systemName: "applewatch")
                        .font(.system(size: Theme.IconSize.lg))
                        .foregroundStyle(.blue)
                        .frame(width: Theme.IconFrame.lg)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text("settings.garminConnect".localized)
                            .font(Theme.headline)
                        Text(isGarminConnected ? "settings.connected".localized : "settings.notConnected".localized)
                            .font(Theme.caption)
                            .foregroundStyle(isGarminConnected ? Theme.success : Theme.secondaryText)
                    }

                    Spacer()

                    Button(isGarminConnected ? "settings.disconnect".localized : "settings.connect".localized) {
                        // TODO: Implement Garmin OAuth flow
                        isGarminConnected.toggle()
                    }
                    .buttonStyle(.bordered)
                    .tint(isGarminConnected ? .red : .blue)
                }
            } footer: {
                Text("Connect your Garmin account to sync workout and health data")
            }
        }
        .navigationTitle("settings.dataConnections".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - NutritionEngine Extensions for Localization

extension NutritionEngine.ActivityLevel {
    var localizedName: String {
        switch self {
        case .sedentary: return "settings.sedentary".localized
        case .light: return "settings.lightActivity".localized
        case .moderate: return "settings.moderateActivity".localized
        case .active: return "settings.activeActivity".localized
        case .veryActive: return "settings.veryActive".localized
        }
    }
}

extension NutritionEngine.GoalType {
    var localizedName: String {
        switch self {
        case .lose: return "settings.loseWeight".localized
        case .maintain: return "settings.maintainWeight".localized
        case .gain: return "settings.gainWeight".localized
        }
    }
}
