//
//  HistoryView.swift
//  AIStream
//
//  Created by Poonam More on 17/02/26.
//

import SwiftUI

// MARK: - History View
//
// Standalone — no NavigationStack inside.
// DashboardView owns the NavigationStack so .searchable and .navigationTitle work.
// Row taps push HistoryChatView directly via NavigationLink(value:).

struct HistoryView: View {

    @StateObject private var viewModel: HistoryViewModel

    init(service: any HistoryServiceProtocol) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(service: service))
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading history…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = viewModel.errorMessage {
                errorView(message: error)
            } else if viewModel.historyItems.isEmpty {
                emptyView
            } else {
                historyList
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search conversations")
        .task { await viewModel.fetchHistory() }
        .refreshable { await viewModel.fetchHistory() }
    }

    // MARK: - List

    private var historyList: some View {
        List {
            ForEach(viewModel.sortedGroupKeys, id: \.self) { key in
                Section {
                    ForEach(viewModel.groupedHistory[key] ?? []) { item in
                        // NavigationLink(value:) — pushes HistoryChatView
                        // DashboardView registers navigationDestination(for: HistoryItem.self)
                        NavigationLink(value: item) {
                            historyRowLabel(item)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text(viewModel.sectionTitle(for: key))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Row Label

    private func historyRowLabel(_ item: HistoryItem) -> some View {
        HStack(spacing: 12) {
            Text(item.conversation_name)
                .font(.body)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundColor(.primary)

            Spacer()

            Text(formattedDisplayDate(for: item))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
        )
    }

    // MARK: - Empty / Error

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No conversations yet")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Button("Retry") {
                Task { await viewModel.fetchHistory() }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
