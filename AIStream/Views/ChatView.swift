//
//  ChatView.swift
//  AIStream
//
//  Created by Poonam More on 12/02/26.
//

import SwiftUI

// MARK: - Layout Constants

private enum BubbleLayout {
    static let maxWidthRatio: CGFloat = 0.82
    static let horizontalPadding: CGFloat = 16
    static let verticalPadding: CGFloat = 12
    static let cornerRadius: CGFloat = 18
}

// MARK: - Haptic Helper

private enum HapticHelper {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Clipboard Helper

private enum ClipboardHelper {
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
        HapticHelper.impact(.medium)
    }
}

// MARK: - ChatView

struct ChatView: View {

    @ObservedObject var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            messagesList
            inputBar
        }
        .navigationTitle("Chats")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.clearError() }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Messages List

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageRow(
                            message: message,
                            isStreaming: viewModel.isStreaming,
                            onFollowUpTap: { followup in
                                viewModel.sendFollowUp(followup)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if let last = viewModel.messages.last {
                                        proxy.scrollTo(last.id, anchor: .bottom)
                                    }
                                }
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.immediately)
            .onChange(of: viewModel.scrollTrigger) { _, _ in
                guard let last = viewModel.messages.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("How can I help you?", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(1...6)
                .focused($isInputFocused)
                .disabled(viewModel.isStreaming)
                .onSubmit {
                    if !viewModel.inputText.contains("\n") {
                        viewModel.sendMessage()
                    }
                }

            if viewModel.canStop {
                Button {
                    viewModel.stopStreaming()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color(.label))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(viewModel.canSend ? Color.accentColor : Color(.systemGray4))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canSend)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
}

// MARK: - MessageRow

struct MessageRow: View {
    let message: ChatMessage
    let isStreaming: Bool
    let onFollowUpTap: (String) -> Void

    @State private var isCopied = false

    private var isCurrentlyStreaming: Bool {
        isStreaming && message.role == .assistant
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 10) {
                if !message.content.isEmpty {
                    messageBubble
                } else if message.role == .assistant {
                    ProgressView()
                        .padding(.horizontal, BubbleLayout.horizontalPadding)
                        .padding(.vertical, BubbleLayout.verticalPadding)
                }

                if message.role == .assistant && !isStreaming && !message.content.isEmpty {
                    if let followups = message.followups, !followups.isEmpty {
                        FollowUpSectionView(
                            followups: followups,
                            isStreaming: isStreaming,
                            onTap: onFollowUpTap
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .bottom)),
                            removal: .opacity
                        ))
                    }

                    if let sources = message.sources, !sources.isEmpty {
                        SourcesSectionView(sources: sources)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                    }
                }
            }
            .frame(
                maxWidth: UIScreen.main.bounds.width * BubbleLayout.maxWidthRatio,
                alignment: message.role == .user ? .trailing : .leading
            )

            if message.role == .assistant { Spacer(minLength: 40) }
        }
        .id(message.id)
        // ── Copied toast — anchored to the whole row, not inside the bubble ──
        .overlay(alignment: .top) {
            if isCopied {
                CopiedToastView()
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.85)),
                        removal: .opacity
                    ))
                    .allowsHitTesting(false)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isCopied)
    }

    // MARK: - Bubble
    //
    // Key architecture decision:
    // The copy button is placed OUTSIDE and BELOW the text bubble in a VStack,
    // NOT inside a ZStack overlaying the text. This ensures zero touch
    // interception — the text bubble owns 100% of its hit-test area so
    // iOS native text selection (long-press → drag → Copy) works correctly.

    @ViewBuilder
    private var messageBubble: some View {
        let isAssistant = message.role == .assistant
        let showCopyButton = isAssistant && !isCurrentlyStreaming && !message.content.isEmpty

        VStack(alignment: .trailing, spacing: 4) {
            // ── Text bubble ──────────────────────────────────────────────
            bubbleContent(isAssistant: isAssistant)

            // ── Copy button sits BELOW the bubble, right-aligned ─────────
            // Completely outside the text area so it never intercepts
            // long-press or selection gestures on the bubble text.
            if showCopyButton {
                copyButton
            }
        }
    }

    // MARK: - Bubble Content

    @ViewBuilder
    private func bubbleContent(isAssistant: Bool) -> some View {
        Group {
            if isAssistant {
                // Single Text(AttributedString) view — enables continuous
                // drag-select across headings, paragraphs and list items.
                // isStreaming disables selection during token streaming.
                MarkdownTextView(
                    content: message.content,
                    isStreaming: isCurrentlyStreaming
                )
            } else {
                Text(message.content)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, BubbleLayout.horizontalPadding)
        .padding(.vertical, BubbleLayout.verticalPadding)
        .frame(
            maxWidth: isAssistant ? .infinity : nil,
            alignment: isAssistant ? .leading : .trailing
        )
        .multilineTextAlignment(isAssistant ? .leading : .trailing)
        .background(isAssistant ? Color(.systemGray6) : Color.accentColor.opacity(0.2))
        .foregroundStyle(.primary)
        .clipShape(RoundedRectangle(cornerRadius: BubbleLayout.cornerRadius, style: .continuous))
        .animation(nil, value: message.content)
    }

    // MARK: - Copy Button (full-message copy)

    private var copyButton: some View {
        Button {
            ClipboardHelper.copy(message.content)
            showCopiedFeedback()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                if isCopied {
                    Text("Copied")
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .foregroundStyle(isCopied ? .green : Color(.systemGray2))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Copy Feedback

    private func showCopiedFeedback() {
        guard !isCopied else { return }
        withAnimation(.easeInOut(duration: 0.2)) { isCopied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeInOut(duration: 0.2)) { isCopied = false }
        }
    }
}

// MARK: - Copied Toast

private struct CopiedToastView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
            Text("Copied to clipboard")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
        .padding(.top, 6)
    }
}

#Preview {
    NavigationStack {
        ChatView(viewModel: ChatViewModel(aiProvider: MockAIProvider()))
    }
}
