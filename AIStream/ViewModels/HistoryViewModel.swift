//
//  ChatViewModel.swift
//  AIStream
//
//  Created by Poonam More on 26/02/26.
//

import Foundation
import Combine

// MARK: - Models

struct HistoryResponse: Decodable {
    let history: [HistoryItem]
}

struct HistoryItem: Identifiable, Decodable, Hashable {
    var id: String { conversation_id }

    let conversation_date: String
    let conversation_id: String
    let conversation_name: String

    /// Parses timestamps like "2026-02-19T13:32:09.626895+05:30"
    /// Tries with fractional seconds first, then falls back to without.
    var date: Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = withFraction.date(from: conversation_date) { return d }

        let withoutFraction = ISO8601DateFormatter()
        withoutFraction.formatOptions = [.withInternetDateTime]
        return withoutFraction.date(from: conversation_date)
    }
}

// MARK: - Date Display Helper

func formattedDisplayDate(for item: HistoryItem) -> String {
    guard let date = item.date else { return item.conversation_date }
    let hours = Calendar.current.dateComponents([.hour], from: date, to: Date()).hour ?? 0
    if hours < 24 {
        let h = max(hours, 1)
        return "\(h) hour\(h == 1 ? "" : "s") ago"
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM yyyy"
    return formatter.string(from: date)
}

// MARK: - ViewModel

@MainActor
final class HistoryViewModel: ObservableObject {

    @Published var historyItems: [HistoryItem] = []
    @Published var groupedHistory: [String: [HistoryItem]] = [:]
    @Published var sortedGroupKeys: [String] = []
    @Published var searchText: String = "" {
        didSet { applySearch() }
    }
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var allItems: [HistoryItem] = []
    private let service: any HistoryServiceProtocol

    init(service: any HistoryServiceProtocol) {
        self.service = service
    }

    func fetchHistory() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let items = try await service.fetchHistory()
            allItems = items.sorted {
                ($0.date ?? .distantPast) > ($1.date ?? .distantPast)
            }
            applySearch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applySearch() {
        let filtered: [HistoryItem]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            filtered = allItems
        } else {
            filtered = allItems.filter {
                $0.conversation_name.localizedCaseInsensitiveContains(searchText)
            }
        }
        historyItems = filtered
        groupHistory(from: filtered)
    }

    private func groupHistory(from items: [HistoryItem]) {
        let calendar = Calendar.current
        let now = Date()

        // Buckets in display order (most recent first)
        // Key is a stable string used as dictionary key AND display label
        let bucketOrder: [String] = [
            "Today",
            "Yesterday",
            "Previous 7 Days",
            "Previous 30 Days"
            // Months are added dynamically below: "February 2026", etc.
        ]

        var groups: [String: [HistoryItem]] = [:]
        var groupLatest: [String: Date] = [:]
        var dynamicMonthKeys: [String] = []    // e.g. ["January 2026", "December 2025"]

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        for item in items {
            guard let date = item.date else { continue }
            let key = bucketKey(for: date, now: now, calendar: calendar, monthFormatter: monthFormatter)

            groups[key, default: []].append(item)

            // Track latest date per bucket for internal sorting (not used for display)
            if let existing = groupLatest[key] {
                groupLatest[key] = max(existing, date)
            } else {
                groupLatest[key] = date
                // Register dynamic month keys in the order we first encounter them
                if !bucketOrder.contains(key) && !dynamicMonthKeys.contains(key) {
                    dynamicMonthKeys.append(key)
                }
            }
        }

        // Month keys arrive in encounter order (items are pre-sorted newest first),
        // so dynamicMonthKeys is already newest-month-first.
        let orderedKeys = (bucketOrder + dynamicMonthKeys).filter { groups[$0] != nil }

        sortedGroupKeys = orderedKeys
        groupedHistory = groups
    }

    /// Maps a date to its section bucket label.
    private func bucketKey(
        for date: Date,
        now: Date,
        calendar: Calendar,
        monthFormatter: DateFormatter
    ) -> String {
        if calendar.isDateInToday(date)     { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let daysAgo = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if daysAgo <= 7  { return "Previous 7 Days" }
        if daysAgo <= 30 { return "Previous 30 Days" }

        return monthFormatter.string(from: date)   // e.g. "January 2026"
    }

    /// Section header title — the key IS the display label in this design.
    func sectionTitle(for key: String) -> String {
        return key
    }
}

