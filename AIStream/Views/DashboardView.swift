//
//  DashboardView.swift
//  AIStream
//
//  Created by Poonam More on 26/02/26.
//

import SwiftUI

// MARK: - Destination Enum
// .history(HistoryItem) renders HistoryChatView directly as the
// NavigationStack root — no back-stack, no stacking on ChatView.

enum SidebarDestination: Hashable {
    case chat
    case projects
    case history(HistoryItem)
}

// MARK: - Dashboard View

struct DashboardView: View {

    @StateObject private var chatViewModel = ServiceContainer.shared.makeChatViewModel()
    @State private var selectedDestination: SidebarDestination = .chat
    @State private var isSidebarVisible: Bool = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isIPad: Bool { sizeClass == .regular }
    private let sidebarWidth: CGFloat = 280

    private let historyService = ServiceContainer.shared.historyService

    var body: some View {
        Group {
            if isIPad {
                ipadLayout
            } else {
                iphoneLayout
            }
        }
    }

    // MARK: - iPad: Persistent Sidebar

    private var ipadLayout: some View {
        HStack(spacing: 0) {
            SidebarView(
                chatViewModel: chatViewModel,
                selectedDestination: $selectedDestination,
                historyService: historyService
            )
            .frame(width: sidebarWidth)

            Divider()

            NavigationStack {
                mainContent
                    .navigationDestination(for: Project.self) { project in
                        ProjectDocumentsView(project: project)
                    }
            }
            .frame(maxWidth: .infinity)
            // Re-create NavigationStack when destination changes so there
            // is never a leftover back-stack from a previous destination
            .id(selectedDestination)
        }
        .ignoresSafeArea(.container, edges: .leading)
    }

    // MARK: - iPhone: Slide-over Sidebar

    private var iphoneLayout: some View {
        ZStack(alignment: .leading) {

            NavigationStack {
                mainContent
                    .navigationDestination(for: Project.self) { project in
                        ProjectDocumentsView(project: project)
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    isSidebarVisible.toggle()
                                }
                            } label: {
                                Image(systemName: "sidebar.left")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                    }
            }
            // Re-create NavigationStack on each destination switch
            .id(selectedDestination)

            // Tap-to-dismiss overlay
            if isSidebarVisible {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            isSidebarVisible = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
            }

            // Sidebar — slides in/out via offset
            SidebarView(
                chatViewModel: chatViewModel,
                selectedDestination: $selectedDestination,
                historyService: historyService,
                onDismiss: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isSidebarVisible = false
                    }
                }
            )
            .frame(width: sidebarWidth)
            .shadow(
                color: isSidebarVisible ? .black.opacity(0.18) : .clear,
                radius: 16, x: 4, y: 0
            )
            .offset(x: isSidebarVisible ? 0 : -sidebarWidth)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSidebarVisible)
            .zIndex(2)
            .ignoresSafeArea(edges: .vertical)
        }
    }

    // MARK: - Main Content
    // Every case is a fresh NavigationStack root — no back button ever appears
    // from sidebar navigation.

    @ViewBuilder
    private var mainContent: some View {
        switch selectedDestination {
        case .chat:
            ChatView(viewModel: chatViewModel)
                .navigationTitle("Chat")
                .navigationBarTitleDisplayMode(.inline)

        case .projects:
            ProjectsView()

        case .history(let item):
            HistoryChatView(
                conversationId: item.conversation_id,
                conversationName: item.conversation_name
            )
        }
    }
}

#Preview {
    DashboardView()
}

