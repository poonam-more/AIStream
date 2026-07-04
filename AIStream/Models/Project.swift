//
//  Project.swift
//  AIStream
//
//
//  Created by Poonam More on 26/02/26.
//

import Foundation

// MARK: - Model

struct Project: Identifiable, Hashable {
    let id: Int
    let project_name: String
    let user_id: Int
    let created_on: Date?

    /// "X hours ago" if within 24h, else "X days ago"
    var displayTime: String {
        guard let date = created_on else { return "Unknown" }
        let components = Calendar.current.dateComponents([.hour, .day], from: date, to: Date())
        let hours = components.hour ?? 0
        let days  = components.day  ?? 0
        if days < 1 {
            let h = max(hours, 1)
            return "\(h) hour\(h == 1 ? "" : "s") ago"
        }
        return "\(days) day\(days == 1 ? "" : "s") ago"
    }
}

// MARK: - Raw Decodable (handles Python-format strings)

/// Intermediate struct that decodes each raw JSON field as a String for manual parsing.
struct RawProject: Decodable {
    let id: Int
    let project_name: String
    let user_id: Int
    let created_on: String   // may be "" or Python datetime string
}

// MARK: - Response

struct ProjectsResponse: Decodable {
    /// The entire "projects" value is a STRING containing a Python list literal.
    let projects: String
}

// MARK: - Python Literal Parser

enum ProjectsParser {

    /// Converts the raw Python-format projects string into [Project].
    ///
    /// Input example:
    /// "[{'id': 146, 'project_name': 'Test Project', 'user_id': 2, 'created_on': datetime.datetime(2026, 1, 29, 12, 34, 38)}]"
    ///
    /// Steps:
    ///   1. Replace single quotes → double quotes
    ///   2. Convert datetime.datetime(Y,M,D,h,m,s) → "YYYY-MM-DDTHH:mm:ss"
    ///   3. Decode as [RawProject]
    ///   4. Parse created_on string → Date
    static func parse(_ raw: String) throws -> [Project] {
        var s = raw

        // 1. Single → double quotes (only outside datetime calls)
        s = s.replacingOccurrences(of: "'", with: "\"")

        // 2. Convert datetime.datetime(2026, 1, 29, 12, 34, 38) → "2026-01-29T12:34:38"
        s = convertDatetimeLiterals(in: s)

        // 3. Decode
        guard let data = s.data(using: .utf8) else {
            throw ProjectsParserError.encodingFailed
        }
        let rawProjects = try JSONDecoder().decode([RawProject].self, from: data)

        // 4. Map to Project
        return rawProjects.map { raw in
            Project(
                id: raw.id,
                project_name: raw.project_name,
                user_id: raw.user_id,
                created_on: parseDate(raw.created_on)
            )
        }
    }

    // MARK: - Private helpers

    /// Regex-replaces all datetime.datetime(...) calls with ISO8601 strings.
    private static func convertDatetimeLiterals(in input: String) -> String {
     
        let pattern = #"datetime\.datetime\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d+)\s*,\s*(\d+)\s*(?:,\s*(\d+)\s*)?)?\)"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }

        var result = input
        let nsInput = input as NSString
        let matches = regex.matches(in: input, range: NSRange(location: 0, length: nsInput.length))

        // Iterate in reverse so replacements don't shift indices
        for match in matches.reversed() {
            func group(_ i: Int) -> String {
                guard match.numberOfRanges > i,
                      match.range(at: i).location != NSNotFound,
                      let r = Range(match.range(at: i), in: input)
                else { return "00" }
                return String(input[r])
            }

            let year   = group(1)
            let month  = group(2).zeroPadded
            let day    = group(3).zeroPadded
            let hour   = group(4).zeroPadded
            let minute = group(5).zeroPadded
            let second = group(6).zeroPadded

            let iso = "\"\(year)-\(month)-\(day)T\(hour):\(minute):\(second)\""

            if let swiftRange = Range(match.range, in: result) {
                result.replaceSubrange(swiftRange, with: iso)
            }
        }
        return result
    }

    private static func parseDate(_ string: String) -> Date? {
        guard !string.isEmpty else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: string) { return d }
        let f2 = DateFormatter()
        f2.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f2.locale = Locale(identifier: "en_US_POSIX")
        return f2.date(from: string)
    }
}

private extension String {
    var zeroPadded: String {
        guard let n = Int(self) else { return "00" }
        return String(format: "%02d", n)
    }
}

enum ProjectsParserError: LocalizedError {
    case encodingFailed
    var errorDescription: String? { "Failed to encode projects string." }
}
