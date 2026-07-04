//
//  StreamEvent.swift
//  AIStream
//
//  Created by Poonam More on 18/02/26.
//

import Foundation

/// Parsed SSE event from streaming API response.
struct StreamEvent: Codable, Sendable {
    let status: String?
    let step: String?
    let streamDetailed: String?
    let summary: String?
    let detailed: String?
    let sources: [SourceItem]?
    let followups: [String]?
    
    enum CodingKeys: String, CodingKey {
        case status, step, summary, detailed, sources, followups
        case streamDetailed = "stream_detailed"
    }
}

/// Source item referenced in AI response.
/// Supports both local files (name + path) and external URLs.
struct SourceItem: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let title: String?
    let url: String?
    let snippet: String?
    let name: String?
    let path: String?

    init(
        id: UUID = UUID(),
        title: String? = nil,
        url: String? = nil,
        snippet: String? = nil,
        name: String? = nil,
        path: String? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.snippet = snippet
        self.name = name
        self.path = path
    }

    enum CodingKeys: String, CodingKey {
        case title, url, snippet, name, path
    }

    init(from decoder: Decoder) throws {
      
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()

        if let container = container {
            self.title = try container.decodeIfPresent(String.self, forKey: .title)
            self.url = try container.decodeIfPresent(String.self, forKey: .url)
            self.snippet = try container.decodeIfPresent(String.self, forKey: .snippet)
            self.name = try container.decodeIfPresent(String.self, forKey: .name)
            self.path = try container.decodeIfPresent(String.self, forKey: .path)
        } else {
            let singleValue = try decoder.singleValueContainer()
            let stringValue = try singleValue.decode(String.self)
            self.title = nil
            self.url = stringValue
            self.snippet = nil
            self.name = nil
            self.path = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        if name != nil || path != nil || title != nil || snippet != nil || (url != nil && (name != nil || path != nil || title != nil || snippet != nil)) {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encodeIfPresent(url, forKey: .url)
            try container.encodeIfPresent(snippet, forKey: .snippet)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(path, forKey: .path)
        } else if let url = url {
            var single = encoder.singleValueContainer()
            try single.encode(url)
        } else {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encodeIfPresent(url, forKey: .url)
            try container.encodeIfPresent(snippet, forKey: .snippet)
            try container.encodeIfPresent(name, forKey: .name)
            try container.encodeIfPresent(path, forKey: .path)
        }
    }

    static func == (lhs: SourceItem, rhs: SourceItem) -> Bool {
        lhs.title == rhs.title &&
        lhs.url == rhs.url &&
        lhs.snippet == rhs.snippet &&
        lhs.name == rhs.name &&
        lhs.path == rhs.path
    }
}
