//
//  ProjectDocument.swift
//  AIStream
//
//  Created by Poonam More on 28/02/26.
//

import Foundation

// MARK: - Models

struct ProjectDocument: Identifiable {
    let id: Int
    let projectId: Int
    let documentName: String
    let documentLocation: String
    let filename: String
}

struct ProjectDocumentsResponse: Decodable {
    let projectdocuments: String
}

// MARK: - Raw Decodable (snake_case from API)

private struct RawProjectDocument: Decodable {
    let id: Int
    let project_id: Int
    let document_name: String
    let document_location: String
    let filename: String
}

// MARK: - Parser

enum ProjectDocumentsParser {

    /// Converts the Python-format string returned by /getprojectdocuments into [ProjectDocument].
    ///
    /// Input: "[{'id': 210, 'project_id': 145, 'document_name': 'file.pdf', ...}]"
    static func parse(_ raw: String) throws -> [ProjectDocument] {
        // Replace single quotes with double quotes for valid JSON
        let jsonString = raw.replacingOccurrences(of: "'", with: "\"")

        guard let data = jsonString.data(using: .utf8) else {
            throw ProjectDocumentsParserError.encodingFailed
        }

        let rawDocs = try JSONDecoder().decode([RawProjectDocument].self, from: data)

        return rawDocs.map {
            ProjectDocument(
                id: $0.id,
                projectId: $0.project_id,
                documentName: $0.document_name,
                documentLocation: $0.document_location,
                filename: $0.filename
            )
        }
    }
}

enum ProjectDocumentsParserError: LocalizedError {
    case encodingFailed
    var errorDescription: String? { "Failed to encode project documents string." }
}

