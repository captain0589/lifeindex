import SwiftUI
import PhotosUI

struct WellnessView: View {
    @EnvironmentObject var healthKitManager: HealthKitManager
    @State private var selectedDate: Date = Date()
    @State private var monthlyMoodLogs: [MoodLog] = []
    @State private var selectedDayLogs: [MoodLog] = []
    @State private var showMoodLogger = false
    @State private var editingLog: MoodLog? = nil
    @State private var loggerDate: Date = Date()

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    // MARK: - Mood Calendar
                    MoodCalendarCard(
                        selectedDate: $selectedDate,
                        monthlyMoodLogs: monthlyMoodLogs,
                        onDateTap: { date in
                            // Single tap opens the mood logger for that date
                            selectedDate = date
                            loggerDate = date
                            loadLogsForSelectedDate()
                            editingLog = nil
                            showMoodLogger = true
                        }
                    )

                    // MARK: - Mood Journal Entries (only show if there are logs)
                    if !selectedDayLogs.isEmpty {
                        MoodJournalSection(
                            date: selectedDate,
                            logs: selectedDayLogs,
                            onEdit: { log in
                                loggerDate = log.date ?? selectedDate
                                editingLog = log
                                showMoodLogger = true
                            },
                            onDelete: { log in
                                deleteMoodLog(log)
                            }
                        )
                        .padding(.horizontal)
                    }

                    // MARK: - Wellness Stats
                    if let mindful = healthKitManager.todaySummary.metrics[.mindfulMinutes] {
                        MindfulnessCard(minutes: mindful)
                            .padding(.horizontal)
                    }

                    if let hrv = healthKitManager.todaySummary.metrics[.heartRateVariability] {
                        StressIndicatorCard(hrv: hrv)
                            .padding(.horizontal)
                    }

                    // Bottom padding for floating button
                    Color.clear.frame(height: 80)
                }
                .padding(.vertical, Theme.Spacing.lg)
            }
            .pageBackground(showGradient: true, gradientHeight: 300)
            .navigationTitle("wellness.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottomTrailing) {
                // Floating Action Button
                Button {
                    loggerDate = Date() // Default to today
                    editingLog = nil
                    showMoodLogger = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(Theme.mood)
                        .clipShape(Circle())
                        .shadow(color: Theme.mood.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(24)
            }
            .sheet(isPresented: $showMoodLogger) {
                MoodLoggerSheet(
                    date: loggerDate,
                    editingLog: editingLog,
                    onSave: { mood, note, image in
                        saveMood(mood: mood, note: note, image: image, date: loggerDate)
                    },
                    onDismiss: {
                        showMoodLogger = false
                        editingLog = nil
                    }
                )
            }
            .onAppear {
                loadMonthlyMoods()
                loadLogsForSelectedDate()
            }
            .onChange(of: selectedDate) { _, _ in
                loadMonthlyMoods()
            }
        }
    }

    private func loadMonthlyMoods() {
        let year = calendar.component(.year, from: selectedDate)
        let month = calendar.component(.month, from: selectedDate)
        monthlyMoodLogs = CoreDataStack.shared.fetchMoodLogsForMonth(year: year, month: month)
    }

    private func loadLogsForSelectedDate() {
        selectedDayLogs = CoreDataStack.shared.fetchMoodLogs(for: selectedDate)
    }

    private func saveMood(mood: Int, note: String?, image: UIImage?, date: Date) {
        var imageFileName: String? = nil
        if let image = image {
            imageFileName = MoodImageManager.shared.saveImage(image)
        }

        if let existingLog = editingLog {
            CoreDataStack.shared.updateMoodLog(existingLog, mood: mood, note: note, imageFileName: imageFileName)
        } else {
            CoreDataStack.shared.saveMoodLog(mood: mood, note: note, imageFileName: imageFileName, date: date)
        }

        loadMonthlyMoods()
        loadLogsForSelectedDate()
    }

    private func deleteMoodLog(_ log: MoodLog) {
        CoreDataStack.shared.deleteMoodLog(log)
        loadMonthlyMoods()
        loadLogsForSelectedDate()
    }
}

// MARK: - Mood Icons (SF Symbol Icons)

private struct MoodIcon {
    // Clean SF Symbol icons representing mood levels
    static let icons = [
        "cloud.bolt.rain.fill",  // Awful - stormy
        "cloud.drizzle.fill",    // Bad - rainy
        "cloud.fill",            // Okay - cloudy
        "cloud.sun.fill",        // Good - partly sunny
        "sun.max.fill"           // Great - sunny
    ]
    static let colors: [Color] = [.red, .orange, .yellow, .mint, .green]
    static let labels = ["Awful", "Bad", "Okay", "Good", "Great"]

    static func icon(for mood: Int) -> String {
        guard mood >= 1 && mood <= 5 else { return "cloud.fill" }
        return icons[mood - 1]
    }

    static func color(for mood: Int) -> Color {
        guard mood >= 1 && mood <= 5 else { return .gray }
        return colors[mood - 1]
    }

    static func label(for mood: Int) -> String {
        guard mood >= 1 && mood <= 5 else { return "Unknown" }
        return labels[mood - 1]
    }
}

// MARK: - Mood Calendar Card

private struct MoodCalendarCard: View {
    @Binding var selectedDate: Date
    let monthlyMoodLogs: [MoodLog]
    let onDateTap: (Date) -> Void

    @State private var currentMonth: Date = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private let weekdays = Calendar.current.shortWeekdaySymbols

    private var year: Int { calendar.component(.year, from: currentMonth) }
    private var month: Int { calendar.component(.month, from: currentMonth) }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    private var daysInMonth: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth),
              let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leadingEmptyDays = firstWeekday - calendar.firstWeekday
        let adjustedLeadingDays = leadingEmptyDays < 0 ? leadingEmptyDays + 7 : leadingEmptyDays

        var days: [Date?] = Array(repeating: nil, count: adjustedLeadingDays)

        for day in range {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                days.append(date)
            }
        }

        return days
    }

    private func moodForDate(_ date: Date) -> Int? {
        let startOfDay = calendar.startOfDay(for: date)
        let logs = monthlyMoodLogs.filter { log in
            guard let logDate = log.date else { return false }
            return calendar.isDate(logDate, inSameDayAs: startOfDay)
        }
        return logs.first.map { Int($0.mood) }
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.mood)
                        .frame(width: 32, height: 32)
                }

                Spacer()

                Text(monthTitle)
                    .font(.system(.headline, design: .rounded, weight: .bold))

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month) ? Theme.tertiaryText : Theme.mood)
                        .frame(width: 32, height: 32)
                }
                .disabled(calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month))
            }

            // Weekday headers
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day.prefix(2))
                        .font(.system(.caption2, design: .rounded, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(height: 20)
                }
            }

            // Calendar grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        CalendarDayButton(
                            date: date,
                            mood: moodForDate(date),
                            isToday: calendar.isDateInToday(date),
                            isFuture: date > Date(),
                            onTap: { onDateTap(date) }
                        )
                    } else {
                        Color.clear.frame(height: 36)
                    }
                }
            }

            // Hint text
            Text("wellness.tapToAdd".localized)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.tertiaryText)
        }
        .padding(Theme.Spacing.md)
        .background(Theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
        .padding(.horizontal)
        .onAppear {
            currentMonth = selectedDate
        }
    }
}

// MARK: - Calendar Day Button

private struct CalendarDayButton: View {
    let date: Date
    let mood: Int?
    let isToday: Bool
    let isFuture: Bool
    let onTap: () -> Void

    private let calendar = Calendar.current

    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack {
                if isToday {
                    Circle()
                        .stroke(Theme.mood, lineWidth: 2)
                }

                if let mood = mood {
                    // Mood SF Symbol icon
                    Image(systemName: MoodIcon.icon(for: mood))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(MoodIcon.color(for: mood))
                } else {
                    Text("\(dayNumber)")
                        .font(.system(.caption, design: .rounded, weight: isToday ? .bold : .regular))
                        .foregroundStyle(isFuture ? Theme.tertiaryText : Theme.primaryText)
                }
            }
            .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }
}

// MARK: - Mood Journal Section

private struct MoodJournalSection: View {
    let date: Date
    let logs: [MoodLog]
    let onEdit: (MoodLog) -> Void
    let onDelete: (MoodLog) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            // Section header
            HStack {
                Text(date.relativeDescription)
                    .font(.system(.headline, design: .rounded, weight: .bold))

                Spacer()

                Text("\(logs.count) " + (logs.count == 1 ? "wellness.entry".localized : "wellness.entries".localized))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            // Mood journal entries
            ForEach(logs) { log in
                MoodJournalCard(log: log, onEdit: onEdit, onDelete: onDelete)
            }
        }
    }
}

// MARK: - Mood Journal Card (Larger, Image-Focused)

private struct MoodJournalCard: View {
    let log: MoodLog
    let onEdit: (MoodLog) -> Void
    let onDelete: (MoodLog) -> Void

    @State private var image: UIImage?
    @State private var showDeleteConfirm = false

    private let imageHeight: CGFloat = 180

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image section (if has image)
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: imageHeight)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else if log.imageFileName != nil {
                // Loading placeholder
                Rectangle()
                    .fill(Theme.tertiaryBackground)
                    .frame(height: imageHeight)
                    .overlay {
                        ProgressView()
                    }
            }

            // Content section
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                // Mood and time row
                HStack {
                    // Mood icon and label
                    HStack(spacing: Theme.Spacing.sm) {
                        Image(systemName: MoodIcon.icon(for: Int(log.mood)))
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(MoodIcon.color(for: Int(log.mood)))

                        Text(MoodIcon.label(for: Int(log.mood)))
                            .font(.system(.title3, design: .rounded, weight: .bold))
                    }

                    Spacer()

                    // Time
                    if let date = log.date {
                        Text(date.formatted(date: .omitted, time: .shortened))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                // Note (if exists)
                if let note = log.note, !note.isEmpty {
                    Text(note)
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(4)
                        .padding(.top, Theme.Spacing.xs)
                }
            }
            .padding(Theme.Spacing.md)
        }
        .background(Theme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.lg))
        .contextMenu {
            Button {
                onEdit(log)
            } label: {
                Label("common.edit".localized, systemImage: "pencil")
            }

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("common.delete".localized, systemImage: "trash")
            }
        }
        .confirmationDialog("wellness.deleteConfirm".localized, isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("common.delete".localized, role: .destructive) {
                onDelete(log)
            }
            Button("common.cancel".localized, role: .cancel) {}
        }
        .task {
            if let fileName = log.imageFileName {
                image = MoodImageManager.shared.loadImage(fileName: fileName)
            }
        }
    }
}

// MARK: - Mood Logger Sheet

struct MoodLoggerSheet: View {
    let date: Date
    let editingLog: MoodLog?
    let onSave: (Int, String?, UIImage?) -> Void
    let onDismiss: () -> Void

    @State private var selectedMood: Int = 3
    @State private var note: String = ""
    @State private var selectedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // Date display
                    Text(date.formatted(date: .complete, time: .omitted))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)

                    // MARK: - Mood Selector with SF Symbol Icons
                    VStack(spacing: Theme.Spacing.lg) {
                        // Selected mood display
                        VStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: MoodIcon.icon(for: selectedMood))
                                .font(.system(size: 64, weight: .medium))
                                .foregroundStyle(MoodIcon.color(for: selectedMood))

                            Text(MoodIcon.label(for: selectedMood))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                                .foregroundStyle(MoodIcon.color(for: selectedMood))
                        }

                        // Mood picker - consistent square buttons
                        HStack(spacing: Theme.Spacing.sm) {
                            ForEach(1...5, id: \.self) { mood in
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        selectedMood = mood
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        Image(systemName: MoodIcon.icon(for: mood))
                                            .font(.system(size: 24, weight: .semibold))
                                            .foregroundStyle(MoodIcon.color(for: mood))

                                        Text(MoodIcon.label(for: mood))
                                            .font(.system(.caption2, design: .rounded, weight: .medium))
                                            .foregroundStyle(selectedMood == mood ? MoodIcon.color(for: mood) : Theme.secondaryText)
                                    }
                                    .frame(width: 64, height: 64)
                                    .background(
                                        selectedMood == mood
                                            ? MoodIcon.color(for: mood).opacity(0.2)
                                            : Theme.tertiaryBackground
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                            .stroke(selectedMood == mood ? MoodIcon.color(for: mood) : Color.clear, lineWidth: 2)
                                    )
                                    .scaleEffect(selectedMood == mood ? 1.05 : 1.0)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // MARK: - Photo Input
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("wellness.addPhoto".localized)
                            .font(Theme.headline)

                        HStack(spacing: Theme.Spacing.sm) {
                            Button {
                                showCamera = true
                            } label: {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "camera.fill")
                                    Text("wellness.takePhoto".localized)
                                }
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                            }

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("wellness.choosePhoto".localized)
                                }
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                            }

                            Spacer()

                            if selectedImage != nil {
                                Button {
                                    selectedImage = nil
                                    selectedPhoto = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(Theme.error)
                                }
                            }
                        }

                        // Photo preview
                        if let image = selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
                        }
                    }
                    .onChange(of: selectedPhoto) {
                        Task { await handlePhotoSelection() }
                    }
                    .fullScreenCover(isPresented: $showCamera) {
                        CameraView(image: $selectedImage)
                            .ignoresSafeArea()
                    }

                    // MARK: - Note Input
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("wellness.journalNote".localized)
                            .font(Theme.headline)

                        TextEditor(text: $note)
                            .frame(minHeight: 120)
                            .padding(Theme.Spacing.sm)
                            .background(Theme.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.md))
                            .overlay(
                                Group {
                                    if note.isEmpty {
                                        Text("wellness.writeThoughts".localized)
                                            .font(.system(.body, design: .rounded))
                                            .foregroundStyle(Theme.tertiaryText)
                                            .padding(Theme.Spacing.md)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                }
                .padding()
            }
            .navigationTitle(editingLog == nil ? "wellness.addMood".localized : "wellness.editMood".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) {
                        onDismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.save".localized) {
                        onSave(selectedMood, note.isEmpty ? nil : note, selectedImage)
                        onDismiss()
                    }
                    .font(.system(.body, design: .rounded, weight: .semibold))
                }
            }
            .onAppear {
                if let log = editingLog {
                    selectedMood = Int(log.mood)
                    note = log.note ?? ""
                    if let fileName = log.imageFileName {
                        selectedImage = MoodImageManager.shared.loadImage(fileName: fileName)
                    }
                }
            }
        }
    }

    private func handlePhotoSelection() async {
        guard let item = selectedPhoto,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            return
        }
        await MainActor.run {
            selectedImage = image
        }
    }
}

// MARK: - Mindfulness Card

struct MindfulnessCard: View {
    let minutes: Double

    var body: some View {
        HStack {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundStyle(Theme.mindfulness)
                .frame(width: Theme.IconFrame.lg)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("wellness.mindfulMinutes".localized)
                    .font(Theme.headline)
                Text("wellness.todaysMindfulness".localized)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer()

            Text("\(Int(minutes)) " + "units.minutes".localized)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(Theme.mindfulness)
        }
        .cardStyle()
    }
}

// MARK: - Stress Indicator Card

struct StressIndicatorCard: View {
    let hrv: Double

    private var stressLevel: String {
        switch hrv {
        case 60...: return "wellness.lowStress".localized
        case 40..<60: return "wellness.moderateStress".localized
        case 20..<40: return "wellness.elevatedStress".localized
        default: return "wellness.highStress".localized
        }
    }

    private var stressColor: Color {
        switch hrv {
        case 60...: return Theme.success
        case 40..<60: return Theme.warning
        case 20..<40: return .orange
        default: return Theme.error
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("wellness.stressLevel".localized)
                .font(Theme.headline)

            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(stressLevel)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundStyle(stressColor)
                    Text(String(format: "wellness.basedOnHRV".localized, "\(Int(hrv))"))
                        .font(Theme.caption)
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                ZStack {
                    Circle()
                        .stroke(stressColor.opacity(0.2), lineWidth: 8)
                        .frame(width: Theme.ComponentSize.ringMedium, height: Theme.ComponentSize.ringMedium)

                    Circle()
                        .trim(from: 0, to: min(1.0, hrv / 100.0))
                        .stroke(stressColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: Theme.ComponentSize.ringMedium, height: Theme.ComponentSize.ringMedium)
                        .rotationEffect(.degrees(-90))

                    Image(systemName: "brain")
                        .foregroundStyle(stressColor)
                }
            }
        }
        .cardStyle()
    }
}
