import SwiftUI
import PhotosUI

struct FoodLogSheet: View {
    @ObservedObject var viewModel: FoodLogViewModel
    @Binding var isPresented: Bool
    @FocusState private var focusedField: Field?

    private enum Field {
        case food, calories
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // MARK: - Food Input
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("What did you eat?")
                            .font(Theme.headline)

                        TextField("e.g. Chicken salad", text: $viewModel.foodDescription)
                            .font(.system(.body, design: .rounded))
                            .focused($focusedField, equals: .food)
                            .padding(Theme.Spacing.md)
                            .background(Theme.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))

                        // Estimate button - separate from text field for better tappability
                        if !viewModel.foodDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                focusedField = nil
                                debugLog("[LifeIndex] Estimate button tapped")
                                Task {
                                    await viewModel.estimateCalories()
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if viewModel.isEstimating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: viewModel.supportsAI ? "sparkles" : "wand.and.stars")
                                    }
                                    Text(viewModel.isEstimating ? "Estimating..." : "Estimate Calories")
                                }
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.calories.opacity(0.15))
                                .foregroundStyle(Theme.calories)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isEstimating)
                        }
                    }

                    // MARK: - Photo Input
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Add a photo")
                            .font(Theme.headline)

                        HStack(spacing: Theme.Spacing.md) {
                            PhotosPicker(
                                selection: $viewModel.selectedPhoto,
                                matching: .images
                            ) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Choose Photo")
                                }
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
                            }

                            if viewModel.selectedImage != nil {
                                Button {
                                    viewModel.selectedImage = nil
                                    viewModel.selectedPhoto = nil
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("Remove")
                                    }
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(.red)
                                }
                            }
                        }

                        // Photo preview
                        if let image = viewModel.selectedImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .frame(maxWidth: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))
                        }
                    }
                    .onChange(of: viewModel.selectedPhoto) {
                        Task { await viewModel.handlePhotoSelection() }
                    }

                    // MARK: - Calories Input
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text("Calories")
                                .font(Theme.headline)
                            if let source = viewModel.estimationSource {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                    Text(source)
                                }
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(Theme.calories)
                                .padding(.horizontal, Theme.Spacing.xs)
                                .padding(.vertical, 2)
                                .background(Theme.calories.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }

                        HStack {
                            TextField("0", text: $viewModel.caloriesText)
                                .keyboardType(.numberPad)
                                .font(.system(.title, design: .rounded, weight: .bold))
                                .focused($focusedField, equals: .calories)
                            Text("kcal")
                                .font(.system(.title3, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.sm))

                        if viewModel.estimationSource != nil {
                            Text("Adjust if needed")
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                    }

                    // MARK: - Macros (Optional)
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Macros (optional)")
                            .font(Theme.headline)

                        HStack(spacing: Theme.Spacing.sm) {
                            MacroField(label: "Protein", text: $viewModel.proteinText, color: .blue)
                            MacroField(label: "Carbs", text: $viewModel.carbsText, color: .orange)
                            MacroField(label: "Fat", text: $viewModel.fatText, color: .pink)
                        }

                        Text("Enter grams for detailed macro tracking")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }

                    // MARK: - Today's Entries
                    if !viewModel.todayLogs.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                            HStack {
                                Text("Today's Entries")
                                    .font(Theme.headline)
                                Spacer()
                                Text("\(viewModel.todayTotal) kcal")
                                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    .foregroundStyle(Theme.calories)
                            }

                            ForEach(viewModel.todayLogs) { log in
                                TodayEntryRow(log: log)
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    viewModel.deleteEntry(viewModel.todayLogs[index])
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.saveEntry() }
                    } label: {
                        Text("Save")
                            .font(.system(.body, design: .rounded, weight: .semibold))
                    }
                    .disabled(!viewModel.canSave)
                }
            }
        }
        .onAppear {
            viewModel.loadTodayLogs()
            focusedField = .food
        }
    }
}

// MARK: - Macro Field

private struct MacroField: View {
    let label: String
    @Binding var text: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(color)
            HStack(spacing: 2) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text("g")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Spacing.xs))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Today Entry Row (with thumbnail)

private struct TodayEntryRow: View {
    let log: FoodLog
    @State private var thumbnail: UIImage?

    private let imageSize: CGFloat = 56

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            // Thumbnail or meal type icon
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize, height: imageSize)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.calories.opacity(0.1))
                    .frame(width: imageSize, height: imageSize)
                    .overlay {
                        Image(systemName: log.mealTypeEnum.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.calories)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                // Name + Time row
                HStack {
                    Text(log.name ?? log.mealTypeEnum.displayName)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .lineLimit(1)

                    Spacer()

                    if let date = log.date {
                        Text(date.timeOnly)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                // Calories
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.calories)
                    Text("\(log.calories) kcal")
                        .font(.system(.caption, design: .rounded, weight: .medium))
                        .foregroundStyle(Theme.calories)
                }

                // Macros (if available)
                if log.protein > 0 || log.carbs > 0 || log.fat > 0 {
                    HStack(spacing: Theme.Spacing.sm) {
                        Label("\(Int(log.protein))g", systemImage: "bolt.fill")
                            .foregroundStyle(.pink)
                        Label("\(Int(log.carbs))g", systemImage: "leaf.fill")
                            .foregroundStyle(.orange)
                        Label("\(Int(log.fat))g", systemImage: "drop.fill")
                            .foregroundStyle(.blue)
                    }
                    .font(.system(.caption2, design: .rounded))
                    .labelStyle(.titleAndIcon)
                }
            }
        }
        .padding(Theme.Spacing.sm)
        .background(Theme.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task {
            if let fileName = log.imageFileName {
                thumbnail = FoodImageManager.shared.loadThumbnail(fileName: fileName, size: imageSize)
            }
        }
    }
}
