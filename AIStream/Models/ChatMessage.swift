//
//  ChatMessage.swift
//  AIStream
//
//  Created by Poonam More on 18/02/26.
//

import Foundation
import Combine

enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var sources: [SourceItem]?
    var followups: [String]?
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        sources: [SourceItem]? = nil,
        followups: [String]? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.sources = sources
        self.followups = followups
    }
}
