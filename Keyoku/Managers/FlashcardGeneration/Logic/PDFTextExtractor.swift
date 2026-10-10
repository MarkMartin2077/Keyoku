//
//  PDFTextExtractor.swift
//  Keyoku
//

import Foundation
import PDFKit

enum PDFExtractionError: LocalizedError {
    case unreadable
    case noPages
    case noText

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return String(localized: "Could not read the PDF. The file may be damaged or password-protected.")
        case .noPages:
            return String(localized: "The PDF has no pages.")
        case .noText:
            return String(localized: "No readable text found in the PDF. It may contain only images or scanned content.")
        }
    }
}

enum PDFTextExtractor {

    /// Runs on the concurrent pool: parsing a long PDF on the main actor freezes the UI.
    @concurrent
    static func extractText(from url: URL) async throws -> (text: String, pageCount: Int) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let document = PDFDocument(url: url) else {
            throw PDFExtractionError.unreadable
        }
        guard document.pageCount > 0 else {
            throw PDFExtractionError.noPages
        }

        var pages: [String] = []
        for index in 0..<document.pageCount {
            try Task.checkCancellation()
            if let text = document.page(at: index)?.string, !text.isEmpty {
                pages.append(text)
            }
        }

        let fullText = pages.joined(separator: "\n\n")
        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PDFExtractionError.noText
        }
        return (fullText, document.pageCount)
    }
}
