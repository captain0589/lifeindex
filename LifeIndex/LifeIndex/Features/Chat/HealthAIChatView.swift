import SwiftUI

struct HealthAIChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @Environment(\.dismiss) private var dismiss
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
                // Background gradient
                LinearGradient(
                    colors: [
                        Theme.background,
                        Theme.background.opacity(0.95),
                        Color.purple.opacity(0.03)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
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
                                                .tint(.purple)
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
    let suggestedQuestions: [SuggestedQuestion]
    let supportsAI: Bool
    let aiUnavailableReason: String?
    let onSelectQuestion: (String) -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // AI Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: supportsAI
                                ? [.purple.opacity(0.3), .blue.opacity(0.2)]
                                : [.gray.opacity(0.2), .gray.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: supportsAI
                                ? [.purple, .blue]
                                : [.gray, .gray.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)

                Image(systemName: supportsAI ? "sparkles" : "cpu")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: Theme.Spacing.xs) {
                Text("chat.welcome.title".localized)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.primaryText)

                Text("chat.welcome.subtitle".localized)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.lg)

                // AI Status indicator
                if supportsAI {
                    HStack(spacing: Theme.Spacing.xs) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("chat.aiPowered".localized)
                            .font(.system(.caption, design: .rounded, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                } else if let reason = aiUnavailableReason {
                    VStack(spacing: Theme.Spacing.xs) {
                        HStack(spacing: Theme.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 10))
                            Text("chat.basicMode".localized)
                                .font(.system(.caption, design: .rounded, weight: .medium))
                        }
                        .foregroundStyle(.orange)

                        Text(reason)
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Theme.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.sm))
                }
            }

            // Suggested questions grid
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
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
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

                // Send button
                Button(action: onSend) {
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

// MARK: - Floating Chat Button

struct FloatingChatButton: View {
    @Binding var showChat: Bool
    @State private var isPulsing = false

    var body: some View {
        Button {
            showChat = true
        } label: {
            ZStack {
                // Pulse ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.purple.opacity(0.5), .blue.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 64, height: 64)
                    .scaleEffect(isPulsing ? 1.2 : 1.0)
                    .opacity(isPulsing ? 0 : 0.5)

                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .shadow(color: .purple.opacity(0.4), radius: 12, x: 0, y: 6)

                // Icon
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: false)
            ) {
                isPulsing = true
            }
        }
    }
}
