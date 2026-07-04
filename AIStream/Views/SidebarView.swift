//
//  SidebarView.swift
//  AIStream
//
//  Created by Poonam More on 26/02/26.
//

import SwiftUI

struct SidebarView: View {

    @ObservedObject var chatViewModel: ChatViewModel
    @Binding var selectedDestination: SidebarDestination
    let historyService: any HistoryServiceProtocol
    var onDismiss: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - App Title
            HStack {
                Text("AIStream")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

            // MARK: - Top Nav Items
            VStack(spacing: 4) {
                SidebarNavButton(
                    title: "Home",
                    icon: "house",
                    isSelected: selectedDestination == .chat
                ) {
                    navigate(to: .chat)
                }

                SidebarNavButton(
                    title: "Projects",
                    icon: "folder",
                    isSelected: selectedDestination == .projects
                ) {
                    navigate(to: .projects)
                }
            }
            .padding(.horizontal, 12)

            Divider()
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

            // MARK: - Chat History
            HistorySidebarListView(
                service: historyService,
                selectedDestination: $selectedDestination,
                onSelect: { item in
                    navigate(to: .history(item))
                }
            )

            Spacer(minLength: 0)

            // MARK: - Sign Out
            Divider()
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            SidebarNavButton(
                title: "Sign Out",
                icon: "rectangle.portrait.and.arrow.right",
                role: .destructive
            ) {
                AppSession.shared.logout()
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 20)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGray6))
    }

    // MARK: - Private

    private func navigate(to destination: SidebarDestination) {
        withAnimation(.easeInOut(duration: 0.22)) {
            selectedDestination = destination
        }
        onDismiss?()
    }
}
