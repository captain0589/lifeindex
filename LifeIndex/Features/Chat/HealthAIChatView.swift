import SwiftUI

struct HealthAIChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isInputFocused: Bool
    @State private var showClearHistoryConfirmation = false

    // Health context builder - allows refreshing with latest data
    var healthContextBuilder: (() -> HealthContext?)?

    // Legacy: direct context (for backwards compatibility)
    var healthContext: HealthContext?

    // Computed property to get the most current context
    private var currentHealthContext: HealthContext? {
        healthContextBuilder?() ?? healthContext
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(colorScheme == .dark ? .systemBackground : .systemGroupedBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: Theme.Spacing.md) {
                                // Welcome message if empty
                                if viewModel.messages.isEmpty {
                                    if viewModel.isReady {
                                        WelcomeSection(
                                            suggestedQuestions: viewModel.suggestedQuestions,
                                            supportsAI: viewModel.supportsAI,
                                            aiUnavailableReason: viewModel.aiUnavailableReason
                                        ) { question in
                                            Task {
                                                await viewModel.sendSuggestedQuestion(question)
                                            }
                                        }
                                        .padding(.top, Theme.Spacing.sm)
                                    } else {
                                        // Loading state while context loads
                                        VStack(spacing: Theme.Spacing.lg) {
                                            ProgressView()
                                                .scaleEffect(1.2)
                                                .tint(.primary)
                                            Text("Loading...")
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundStyle(Theme.secondaryText)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, Theme.Spacing.xl * 2)
                                    }
                                }

                                // Messages
                                ForEach(viewModel.messages) { message in
                                    ChatBubble(
                                        message: message,
                                        shouldAnimate: viewModel.animatingMessageIds.contains(message.id),
                                        onAnimationComplete: {
                                            viewModel.markAnimationComplete(for: message.id)
                                        }
                                    )
                                    .id(message.id)
                                }

                                // Invisible anchor at the bottom for scrolling
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.bottom, Theme.Spacing.md)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .defaultScrollAnchor(.bottom)
                        .onChange(of: viewModel.messages.count) { oldCount, newCount in
                            // When AI responds, scroll to start of the new message
                            if let lastMessage = viewModel.messages.last {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    // Scroll to the new message with top anchor so user sees start of response
                                    proxy.scrollTo(lastMessage.id, anchor: .top)
                                }
                            }
                        }
                        .onChange(of: isInputFocused) { _, focused in
                            // Scroll to bottom when keyboard appears
                            if focused {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }

                    // Quick suggestions (when chatting and not generating)
                    if !viewModel.messages.isEmpty && !viewModel.isGenerating && !viewModel.followUpQuestions.isEmpty {
                        QuickSuggestionsBar(questions: viewModel.followUpQuestions) { question in
                            Task {
                                await viewModel.sendSuggestedQuestion(question)
                            }
                        }
                    }

                    // Input bar
                    ChatInputBar(
                        text: $viewModel.inputText,
                        isGenerating: viewModel.isGenerating,
                        isFocused: $isInputFocused
                    ) {
                        Task {
                            await viewModel.sendMessage()
                        }
                    }
                }
            }
            .navigationTitle("chat.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.tertiaryText)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.startNewSession()
                        } label: {
                            Label("chat.newChat".localized, systemImage: "plus.bubble")
                        }

                        if !viewModel.sessions.isEmpty {
                            Divider()

                            Section("chat.history".localized) {
                                ForEach(viewModel.sessions.prefix(5)) { session in
                                    Button {
                                        viewModel.loadSession(session)
                                    } label: {
                                        Label(session.displayTitle, systemImage: "bubble.left.and.bubble.right")
                                    }
                                }
                            }

                            Divider()

                            Button(role: .destructive) {
                                showClearHistoryConfirmation = true
                            } label: {
                                Label("chat.clearHistory".localized, systemImage: "trash")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.accentColor)
                    }
                }
            }
            .alert("chat.clearHistory".localized, isPresented: $showClearHistoryConfirmation) {
                Button("common.cancel".localized, role: .cancel) { }
                Button("chat.clearHistory".localized, role: .destructive) {
                    viewModel.clearAllHistory()
                }
            } message: {
                Text("chat.clearHistoryConfirm".localized)
            }
            .onAppear {
                viewModel.updateHealthContext(currentHealthContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Refresh context when app becomes active
                if newPhase == .active {
                    viewModel.updateHealthContext(currentHealthContext)
                }
            }
        }
    }
}

// MARK: - Welcome Section

private struct WelcomeSection: View {
    @Environment(\.colorScheme) var colorScheme
    let suggestedQuestions: [SuggestedQuestion]
    let supportsAI: Bool
    let aiUnavailableReason: String?
    let onSelectQuestion: (String) -> Void

    private var features: [(icon: String, color: Color, title: String, subtitle: String)] {
        [
            ("message.fill",       Color(red: 0.35, green: 0.85, blue: 0.75), "chat.feature.guidance.title".localized,     "chat.feature.guidance.subtitle".localized),
            ("sparkles",           Color(red: 0.95, green: 0.45, blue: 0.55), "chat.feature.suggestions.title".localized, "chat.feature.suggestions.subtitle".localized),
            ("brain.head.profile", Color(red: 0.55, green: 0.60, blue: 0.95), "chat.feature.memory.title".localized,      "chat.feature.memory.subtitle".localized)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Lottie Icon ──────────────────────────────────────────
            Group {
                if supportsAI {
                    AIAnimatedIcon(size: 80)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 80)
                        Image(systemName: "cpu")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.md)

            // ── Title ─────────────────────────────────────────────────
            ZStack {
                // Aura glow behind the text
                Text("chat.title".localized)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(red: 1.0, green: 0.75, blue: 0.55), Color(red: 0.95, green: 0.60, blue: 0.75), Color(red: 0.80, green: 0.75, blue: 1.0)]
                                : [Color(red: 0.90, green: 0.45, blue: 0.10), Color(red: 0.75, green: 0.35, blue: 0.65), Color(red: 0.45, green: 0.45, blue: 0.90)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .blur(radius: 18)
                    .opacity(colorScheme == .dark ? 0.7 : 0.4)

                // Gradient text
                Text("chat.title".localized)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [Color(red: 1.0, green: 0.80, blue: 0.60), Color(red: 0.96, green: 0.96, blue: 0.98), Color(red: 0.75, green: 0.80, blue: 1.0)]
                                : [Color(red: 0.85, green: 0.40, blue: 0.05), Color(red: 0.70, green: 0.30, blue: 0.60), Color(red: 0.40, green: 0.40, blue: 0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .multilineTextAlignment(.center)
            .overlay(alignment: .topTrailing) {
                Text("Beta")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        LinearGradient(colors: [.orange, .pink],
                                       startPoint: .leading,
                                       endPoint: .trailing)
                    )
                    .clipShape(Capsule())
                    .offset(x: 6, y: -10)
            }
            .padding(.bottom, Theme.Spacing.xl)
            VStack(spacing: Theme.Spacing.lg) {
                ForEach(features, id: \.title) { feature in
                    HStack(spacing: Theme.Spacing.md) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(feature.color.opacity(0.18))
                                .frame(width: 44, height: 44)
                            Image(systemName: feature.icon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(feature.color)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feature.title)
                                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                .foregroundStyle(Theme.primaryText)
                            Text(feature.subtitle)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.xl)

            // ── AI unavailable reason ─────────────────────────────────
            if !supportsAI, let reason = aiUnavailableReason {
                Text(reason)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.tertiaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.lg)
            }

            // ── Suggested question chips ──────────────────────────────
            VStack(spacing: Theme.Spacing.sm) {
                Text("chat.suggestions".localized)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
                    ForEach(suggestedQuestions.prefix(6)) { question in
                        SuggestionCard(question: question) {
                            onSelectQuestion(question.text)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.sm)
        }
    }
}

// MARK: - Suggestion Card

private struct SuggestionCard: View {
    let question: SuggestedQuestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: question.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(question.category.color)
                    .frame(width: 24)

                Text(question.text)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                    .fill(Theme.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.md)
                            .stroke(question.category.color.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: ChatMessage
    let shouldAnimate: Bool
    let onAnimationComplete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            if message.isUser {
                Spacer(minLength: 60)
            } else {
                // AI Avatar
                AIAvatarIcon(size: 28)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: Theme.Spacing.xxs) {
                if message.isTyping {
                    TypingIndicator()
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                                .fill(Theme.secondaryBackground)
                        )
                } else {
                    // Use animated text for AI messages that should animate
                    Group {
                        if !message.isUser && shouldAnimate {
                            AnimatedTextView(
                                fullText: message.content,
                                isAnimating: true,
                                onComplete: onAnimationComplete
                            )
                        } else {
                            Text(message.content)
                        }
                    }
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(message.isUser ? .white : Theme.primaryText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.CornerRadius.lg)
                            .fill(
                                message.isUser
                                    ? LinearGradient(
                                        colors: [Theme.accentColor, Theme.accentColor.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        colors: [Theme.secondaryBackground, Theme.secondaryBackground],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                            )
                    )

                    Text(message.timestamp, style: .time)
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Theme.tertiaryText)
                }
            }

            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var animationOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Theme.tertiaryText)
                    .frame(width: 8, height: 8)
                    .offset(y: animationOffset)
                    .animation(
                        Animation.easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                        value: animationOffset
                    )
            }
        }
        .onAppear {
            animationOffset = -5
        }
    }
}

// MARK: - Animated Text View (Typing Effect)

private struct AnimatedTextView: View {
    let fullText: String
    let isAnimating: Bool
    let onComplete: () -> Void

    @State private var displayedText: String = ""
    @State private var currentIndex: Int = 0

    // Speed: characters per second (higher = faster)
    private let charactersPerSecond: Double = 80

    var body: some View {
        Text(displayedText)
            .onAppear {
                if isAnimating {
                    startAnimation()
                } else {
                    displayedText = fullText
                }
            }
            .onChange(of: fullText) { _, newValue in
                if isAnimating && displayedText.isEmpty {
                    startAnimation()
                }
            }
    }

    private func startAnimation() {
        displayedText = ""
        currentIndex = 0
        animateNextCharacter()
    }

    private func animateNextCharacter() {
        guard currentIndex < fullText.count else {
            onComplete()
            return
        }

        let index = fullText.index(fullText.startIndex, offsetBy: currentIndex)
        displayedText.append(fullText[index])
        currentIndex += 1

        // Vary speed slightly for more natural feel
        let baseDelay = 1.0 / charactersPerSecond
        let delay = baseDelay * Double.random(in: 0.8...1.2)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            animateNextCharacter()
        }
    }
}

// MARK: - Quick Suggestions Bar

private struct QuickSuggestionsBar: View {
    let questions: [SuggestedQuestion]
    let onSelectQuestion: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(questions) { question in
                    Button {
                        onSelectQuestion(question.text)
                    } label: {
                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: question.icon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(question.text)
                                .font(.system(.subheadline, design: .rounded, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(question.category.color)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .frame(minHeight: 44)
                        .background(
                            Capsule()
                                .fill(question.category.color.opacity(0.12))
                                .overlay(
                                    Capsule()
                                        .stroke(question.category.color.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
        }
        .padding(.vertical, Theme.Spacing.sm)
        .background(Theme.background.opacity(0.95))
    }
}

// MARK: - Chat Input Bar

private struct ChatInputBar: View {
    @Binding var text: String
    let isGenerating: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    private var sendButtonGradient: LinearGradient {
        let isDisabled = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating
        if isDisabled {
            return LinearGradient(
                colors: [Theme.tertiaryText.opacity(0.3), Theme.tertiaryText.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Theme.accentColor, Theme.accentColor.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Text field
            HStack(spacing: Theme.Spacing.sm) {
                TextField("chat.placeholder".localized, text: $text, axis: .vertical)
                    .font(.system(.subheadline, design: .rounded))
                    .lineLimit(1...4)
                    .focused(isFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating {
                            // Defocus to stop any voice input
                            isFocused.wrappedValue = false
                            onSend()
                        }
                    }

                // Send button
                Button {
                    // Defocus to stop any voice input before sending
                    isFocused.wrappedValue = false
                    onSend()
                } label: {
                    ZStack {
                        Circle()
                            .fill(sendButtonGradient)
                            .frame(width: 36, height: 36)

                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isGenerating)
            }
            .padding(.leading, Theme.Spacing.md)
            .padding(.trailing, Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Theme.tertiaryText.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
            Theme.background
                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
    }
}

