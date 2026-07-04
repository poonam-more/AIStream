//
//  TextNormalizer.swift
//  AIStream
//
//  Created by Poonam More on 19/02/26.
//

import Foundation

/// Utilities for normalizing and preserving text formatting during streaming.
enum TextNormalizer {

    /// Normalizes escaped newlines and preserves all whitespace.
    /// Converts `\\n` → `\n`, `\\t` → `\t`, `\\r` → `\r`.
    /// Does NOT manipulate `**` markers — those are handled at render time in MarkdownTextView.
    static func normalizeEscapedNewlines(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "\\n", with: "\n")
        result = result.replacingOccurrences(of: "\\t", with: "\t")
        result = result.replacingOccurrences(of: "\\r", with: "\r")
        return result
    }

    /// Safely appends a chunk to existing text, preserving all whitespace and newlines.
    /// Never trims content — preserves exact formatting.
    static func appendChunk(existing: String, chunk: String) -> String {
        let normalizedChunk = normalizeEscapedNewlines(chunk)
        return existing + normalizedChunk
    }

    /// Debug helper: Logs newline presence in text for verification.
    static func debugNewlines(_ text: String, label: String = "Text") {
        #if DEBUG
        let newlineCount = text.filter { $0 == "\n" }.count
        let doubleNewlineCount = text.components(separatedBy: "\n\n").count - 1
        let escapedNewlineCount = text.components(separatedBy: "\\n").count - 1
        _ = newlineCount; _ = doubleNewlineCount; _ = escapedNewlineCount
        #endif
    }
}

