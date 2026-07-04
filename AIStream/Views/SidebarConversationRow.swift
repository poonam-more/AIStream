//
//  SidebarRow.swift
//  AIStream
//
//  Created by Poonam More on 26/02/26.
//

import SwiftUI

// MARK: - History Conversation Row (used in standalone HistoryTabView)

struct SidebarConversationRow: View {

    let item: HistoryItem
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 18)

                Text(item.conversation_name)
                    .font(.system(size: 15))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.accentColor
                            : isHovered ? Color(.systemGray5) : Color.clear
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}

// MARK: - Sidebar Nav Button

struct SidebarNavButton: View {

    let title: String
    let icon: String
    let role: ButtonRole?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    init(
        title: String,
        icon: String,
        role: ButtonRole? = nil,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.role = role
        self.isSelected = isSelected
        self.action = action
    }

    private var foregroundColor: Color {
        if role == .destructive { return .red }
        if isSelected { return .accentColor }
        return .primary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(foregroundColor)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(foregroundColor)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)           // taller touch target
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? Color.accentColor.opacity(0.12)
                            : isHovered ? Color(.systemGray5) : Color.clear
                    )
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }
}
