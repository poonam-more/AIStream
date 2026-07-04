//
//  SourcesSectionView.swift
//  AIStream
//
//  Created by Poonam More on 19/02/26.
//
import SwiftUI

/// Displays sources as expandable rows with icons and links.
/// Handles both local files and external URLs.
struct SourcesSectionView: View {
    let sources: [SourceItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sources:")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            
            LazyVStack(spacing: 8) {
                ForEach(sources) { source in
                    SourceRow(source: source)
                }
            }
        }
        .padding(16)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

/// Individual source row with icon and link.
private struct SourceRow: View {
    let source: SourceItem
    @State private var isExpanded = false
    
    private var displayName: String {
        source.name ?? source.title ?? source.url ?? source.path ?? source.snippet ?? "Source"
    }
    
    private var isURL: Bool {
        if let url = source.url {
            return url.hasPrefix("http://") || url.hasPrefix("https://")
        }
        return false
    }
    
    private var isLocalFile: Bool {
        source.path != nil || (source.name != nil && source.url == nil)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                if isURL, let urlString = source.url, let url = URL(string: urlString) {
                    openURL(url)
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }) {
                HStack(spacing: 12) {
                    // Icon based on source type
                    Group {
                        if isURL {
                            Image(systemName: "link.circle.fill")
                                .foregroundStyle(.blue)
                        } else if isLocalFile {
                            Image(systemName: "doc.text.fill")
                                .foregroundStyle(.secondary)
                        } else {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 18))
                    
                    // Source name/title
                    Text(displayName)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .lineLimit(isExpanded ? nil : 1)
                    
                    Spacer()
                    
                    // Expand/collapse indicator for local files
                    if isLocalFile && source.snippet != nil {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else if isURL {
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 14))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            
            // Expanded snippet for local files
            if isExpanded, let snippet = source.snippet {
                Text(snippet)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    /// Opens URL in Safari.
    private func openURL(_ url: URL) {
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }
}

#Preview {
    VStack(spacing: 20) {
        SourcesSectionView(sources: [
            SourceItem(title: "Documentation", url: "https://example.com/docs", snippet: nil),
            SourceItem(title: "API Reference", url: "https://example.com/api", snippet: nil),
            SourceItem(title: "Local File", url: nil, snippet: "This is a snippet of content from the local file that can be expanded.")
        ])
    }
    .padding()
}
