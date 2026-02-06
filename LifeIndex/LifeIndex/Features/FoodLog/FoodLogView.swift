import SwiftUI
import PhotosUI

struct FoodLogSheet: View {
    @ObservedObject var viewModel: FoodLogViewModel
    @Binding var isPresented: Bool
    @FocusState private var focusedField: Field?
    @State private var showCamera = false
    @State private var showPhotoSourceOptions = false

    private enum Field {
        case food, calories
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    // MARK: - Food Input
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("food.whatDidYouEat".localized)
                            .font(Theme.headline)

                        TextField("food.placeholder".localized, text: $viewModel.foodDescription)
                            .font(.system(.body, design: .rounded))
                            .focused($focusedField, equals: .food)
                            .padding(Theme.Spacing.md)
                            .background(Theme.tertiaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))

                        // Estimate button - separate from text field for better tappability
                        if !viewModel.foodDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button {
                                focusedField = nil
                                debugLog("[LifeIndex] Estimate button tapped")
                                Task {
                                    await viewModel.estimateCalories()
                                }
                            } label: {
                                HStack(spacing: Theme.Spacing.xs) {
                                    if viewModel.isEstimating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: viewModel.supportsAI ? "sparkles" : "wand.and.stars")
                                    }
                                    Text(viewModel.isEstimating ? "food.estimating".localized : "food.estimateCalories".localized)
                                }
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.calories.opacity(0.15))
                                .foregroundStyle(Theme.calories)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isEstimating)
                        }
                    }

                    // MARK: - Photo Input
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("food.addPhoto".localized)
                            .font(Theme.headline)

                        HStack(spacing: Theme.Spacing.sm) {
                            // Camera button
                            Button {
                                showCamera = true
                            } label: {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "camera.fill")
                                    Text("Take Photo")
                                }
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                            }

                            // Photo library picker
                            PhotosPicker(
                                selection: $viewModel.selectedPhoto,
                                matching: .images
                            ) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("food.choosePhoto".localized)
                                }
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .padding(.horizontal, Theme.Spacing.md)
                                .padding(.vertical, Theme.Spacing.sm)
                                .background(Theme.tertiaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                            }

                            Spacer()

                            if viewModel.selectedImage != nil {
                                Button {
                                    viewModel.selectedImage = nil
                                    viewModel.selectedPhoto = nil
                                } label: {
                                    HStack(spacing: Theme.Spacing.xs) {
                                        Image(systemName: "xmark.circle.fill")
                                        Text("food.removePhoto".localized)
                                    }
                                    .font(.system(.caption, design: .rounded, weight: .medium))
                                    .foregroundStyle(Theme.error)
                                }
                            }
                        }

                        // Photo preview
                        if let image = viewModel.selectedImage {
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                                .fill(Theme.tertiaryBackground)
                                .frame(height: 200)
                                .frame(maxWidth: .infinity)
                                .overlay {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFit()
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                                        .padding(Theme.Spacing.sm)
                                }
                        }
                    }
                    .onChange(of: viewModel.selectedPhoto) {
                        Task { await viewModel.handlePhotoSelection() }
                    }
                    .fullScreenCover(isPresented: $showCamera) {
                        CameraView(image: $viewModel.selectedImage)
                            .ignoresSafeArea()
                    }

                    // MARK: - Calories Input
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        HStack {
                            Text("food.calories".localized)
                                .font(Theme.headline)
                            if let source = viewModel.estimationSource {
                                HStack(spacing: Theme.Spacing.xs) {
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
                            Text("units.kcal".localized)
                                .font(.system(.title3, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        .padding(Theme.Spacing.md)
                        .background(Theme.tertiaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))

                        if viewModel.estimationSource != nil {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                Text("food.adjustIfNeeded".localized)
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)

                                // AI reasoning explanation
                                if let reason = viewModel.estimationReason, !reason.isEmpty {
                                    HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                                        Image(systemName: "info.circle")
                                            .font(.system(.caption2))
                                            .foregroundStyle(Theme.calories.opacity(0.8))
                                        Text(reason)
                                            .font(.system(.caption2, design: .rounded))
                                            .foregroundStyle(Theme.tertiaryText)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .padding(.top, 2)
                                }
                            }
                        }
                    }

                    // MARK: - Macros (Optional)
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("food.macrosOptional".localized)
                            .font(Theme.headline)

                        HStack(spacing: Theme.Spacing.sm) {
                            MacroField(labelKey: "food.protein", text: $viewModel.proteinText, color: .blue)
                            MacroField(labelKey: "food.carbs", text: $viewModel.carbsText, color: .orange)
                            MacroField(labelKey: "food.fat", text: $viewModel.fatText, color: .pink)
                        }

                        Text("food.enterMacros".localized)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }

                }
                .padding()
            }
            .navigationTitle("food.logFood".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.cancel".localized) {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.saveEntry() }
                    } label: {
                        Text("common.save".localized)
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
        .onChange(of: viewModel.didSave) { _, didSave in
            if didSave {
                isPresented = false
            }
        }
    }
}

// MARK: - Macro Field

private struct MacroField: View {
    let labelKey: String
    @Binding var text: String
    let color: Color

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(labelKey.localized)
                .font(.system(.caption2, design: .rounded, weight: .medium))
                .foregroundStyle(color)
            HStack(spacing: 2) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .font(.system(.body, design: .rounded, weight: .semibold))
                    .multilineTextAlignment(.center)
                Text("food.grams".localized)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.tertiaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.xs))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
