//
//  HistorySidebarListView.swift
//  AIStream
//

import SwiftUI

struct HistorySidebarListView: View {

    @StateObject private var viewModel: HistoryViewModel
    @Binding var selectedDestination: SidebarDestination
    var onSelect: ((HistoryItem) -> Void)? = nil

    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    init(
        service: any HistoryServiceProtocol,
        selectedDestination: Binding<SidebarDestination>,
        onSelect: ((HistoryItem) -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: HistoryViewModel(service: service))
        _selectedDestination = selectedDestination
        self.onSelect = onSelect
    }

    private var selectedId: String? {
        if case .history(let item) = selectedDestination {
            return item.conversation_id
        }
        return nil
    }

    // Filter items based on local searchText
    private var filteredKeys: [String] {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else {
            return viewModel.sortedGroupKeys
        }
        return viewModel.sortedGroupKeys.filter { key in
            (viewModel.groupedHistory[key] ?? []).contains { item in
                item.conversation_name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func filteredItems(for key: String) -> [HistoryItem] {
        let items = viewModel.groupedHistory[key] ?? []
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return items }
        return items.filter { $0.conversation_name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // MARK: - Header row
            HStack {
                Text("Chat History")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                if viewModel.isLoading {
                    ProgressView().scaleEffect(0.65)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            // MARK: - Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                TextField("Search conversations", text: $searchText)
                    .font(.system(size: 13))
                    .focused($isSearchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        isSearchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(.systemGray5))
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .animation(.easeInOut(duration: 0.15), value: searchText.isEmpty)

            // MARK: - Content

            if viewModel.errorMessage != nil {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                    Text("Failed to load")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Retry") {
                        Task { await viewModel.fetchHistory() }
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tint)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

            } else if !viewModel.isLoading && filteredKeys.isEmpty {
                VStack(spacing: 6) {
                    if searchText.isEmpty {
                        Text("No conversations yet")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22))
                            .foregroundStyle(.tertiary)
                            .padding(.bottom, 2)
                        Text("No results for \"\(searchText)\"")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)

            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(filteredKeys, id: \.self) { key in

                            // Group label — hidden during active search to keep UI clean
                            if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text(viewModel.sectionTitle(for: key))
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 10)
                                    .padding(.bottom, 2)
                            }

                            ForEach(filteredItems(for: key)) { item in
                                SidebarConversationRow(
                                    item: item,
                                    isSelected: selectedId == item.conversation_id,
                                    onTap: {
                                        isSearchFocused = false
                                        onSelect?(item)
                                    }
                                )
                                .padding(.horizontal, 12)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .task { await viewModel.fetchHistory() }
    }
}

