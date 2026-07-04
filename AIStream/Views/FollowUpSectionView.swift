//
//  FollowUpSectionView.swift
//  AIStream
//
//  Created by Poonam More on 19/02/26.
//

import SwiftUI

/// Displays follow-up questions as tappable buttons in a card-style container.
/// Shown after AI message completes streaming.
struct FollowUpSectionView: View {
    let followups: [String]
    let isStreaming: Bool
    let onTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Follow-up Questions:")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            
            LazyVStack(spacing: 8) {
                ForEach(followups, id: \.self) { followup in
                    FollowUpButton(
                        text: followup,
                        isEnabled: !isStreaming,
                        onTap: { onTap(followup) }
                    )
                }
            }
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

/// Individual follow-up question button.
private struct FollowUpButton: View {
    let text: String
    let isEnabled: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            onTap()
        }) {
            HStack {
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(isEnabled ? .primary : .secondary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(isEnabled ? Color.accentColor : Color(.systemGray4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isEnabled ? Color(.systemBackground) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled ? Color(.systemGray4) : Color(.systemGray5), lineWidth: 0.5)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

#Preview {
    VStack(spacing: 20) {
        FollowUpSectionView(
            followups: [
                "What are the key features?",
                "How does it work?",
                "Tell me more about the implementation"
            ],
            isStreaming: false,
            onTap: { print("Tapped: \($0)") }
        )
        
        FollowUpSectionView(
            followups: ["Disabled question"],
            isStreaming: true,
            onTap: { print("Tapped: \($0)") }
        )
    }
    .padding()
}
