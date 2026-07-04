//
//  HistoryChatView.swift
//  AIStream
//
//  Created by Poonam More on 27/02/26.
//

import SwiftUI

struct HistoryChatView: View {

    @StateObject private var viewModel: HistoryChatViewModel
    @FocusState private var isInputFocused: Bool

    init(conversationId: String, conversationName: String = "Conversation") {
        _viewModel = StateObject(
            wrappedValue: ServiceContainer.shared.makeHistoryChatViewModel(
                conversationId: conversationId,
                conversationName: conversationName
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.messages.isEmpty && viewModel.errorMessage == nil {
                    emptyView
                } else {
                    messagesList
                }
            }

            // ── Input bar — always visible, same as ChatView ──────────
            inputBar
        }
        .navigationTitle(viewModel.conversationName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadConversation() }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("Retry") {
                Task { await viewModel.loadConversation() }
            }
            Button("Dismiss") { viewModel.clearError() }
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
        .onDisappear { viewModel.stopStreaming() }
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

                Color.clear
                    .frame(height: 1)
                    .id("bottom")
            }
            .scrollDismissesKeyboard(.immediately)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.scrollTrigger) { _, _ in
                guard let last = viewModel.messages.last else { return }
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("What would you like to know next?", text: $viewModel.inputText, axis: .vertical)
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
                        .background(Color.black)
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

    // MARK: - States

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading conversation…")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No messages found")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
