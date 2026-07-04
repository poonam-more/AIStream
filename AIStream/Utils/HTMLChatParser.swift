//
//  HTMLChatParser.swift
//  AIStream
//
//  Created by Poonam More on 28/02/26.
//

import Foundation

// MARK: - HTML Chat Parser

enum HTMLChatParser {

    /// Parses an HTML string containing chat divs into an ordered [ChatMessage].
    ///
    /// Expected input structure:
    ///   <div class="chat outgoing">...<p>User message</p>...</div>
    ///   <div class="chat incoming">...<p>Bot response</p>...</div>
    ///
    /// - outgoing → MessageRole.user
    /// - incoming → MessageRole.assistant
    static func parse(_ html: String) -> [ChatMessage] {
        var messages: [ChatMessage] = []

        // Match every <div class="chat outgoing|incoming">...</div> block
        // Use a regex that captures the class and the full inner content
        let pattern = #"<div[^>]*class="chat\s+(outgoing|incoming)"[^>]*>([\s\S]*?)</div>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        let nsHTML = html as NSString
        let matches = regex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        for match in matches {
            guard match.numberOfRanges >= 3,
                  let typeRange    = Range(match.range(at: 1), in: html),
                  let contentRange = Range(match.range(at: 2), in: html)
            else { continue }

            let typeString  = String(html[typeRange]).lowercased()
            let innerHTML   = String(html[contentRange])
            let role: MessageRole = typeString == "outgoing" ? .user : .assistant

            // Extract text from all <p> tags inside this block
            let text = extractText(from: innerHTML)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }

            messages.append(ChatMessage(role: role, content: text))
        }

        return messages
    }

    // MARK: - Private helpers

    /// Extracts and concatenates text from all <p> tags, stripping inner HTML tags.
    private static func extractText(from html: String) -> String {
        let pPattern = #"<p[^>]*>([\s\S]*?)</p>"#
        guard let pRegex = try? NSRegularExpression(pattern: pPattern, options: [.caseInsensitive]) else {
            return stripTags(html)
        }

        let nsHTML = html as NSString
        let pMatches = pRegex.matches(in: html, range: NSRange(location: 0, length: nsHTML.length))

        if pMatches.isEmpty {
            // No <p> tags — strip all tags from raw content
            return stripTags(html)
        }

        let paragraphs = pMatches.compactMap { m -> String? in
            guard m.numberOfRanges >= 2,
                  let r = Range(m.range(at: 1), in: html)
            else { return nil }
            let inner = stripTags(String(html[r]))
            return inner.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        return paragraphs.joined(separator: "\n\n")
    }

    /// Removes all HTML tags and decodes common HTML entities.
    private static func stripTags(_ html: String) -> String {
        // Remove all HTML tags
        var result = html.replacingOccurrences(
            of: "<[^>]+>",
            with: "",
            options: .regularExpression
        )
        // Decode common HTML entities
        result = result
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "<br>",   with: "\n")
            .replacingOccurrences(of: "<br/>",  with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")

        return result
    }
}
