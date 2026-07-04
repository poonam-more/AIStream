//
//  MarkdownTextView.swift
//  AIStream
//
//  Created by Poonam More on 19/02/26.
//

import SwiftUI
import UIKit

// MARK: - MarkdownTextView
//
// Renders markdown as a NON-EDITABLE UITextView so the user gets the exact
// same native iOS text-selection UX as ChatGPT:
//   • Long-press  → blue highlight + two round drag handles appear
//   • Drag handle → extends selection across paragraphs / headings / lists
//   • Release     → native Copy / Share popup
//
// SwiftUI's Text(.textSelection(.enabled)) does NOT produce this UX —
// it shows a cursor but no handles/highlight. UITextView does it correctly.

struct MarkdownTextView: View {
    let content: String
    var isStreaming: Bool = false

    var body: some View {
        SelectableTextView(
            attributedText: Self.buildAttributedString(content),
            isSelectable: !isStreaming
        )
        .animation(nil, value: content)
        .transaction { $0.animation = nil }
    }

    // MARK: - AttributedString Builder

    static func buildAttributedString(_ text: String) -> NSAttributedString {
        let normalized = TextNormalizer.normalizeEscapedNewlines(text)
        let blocks = parse(normalized)

        let result = NSMutableAttributedString()

        for (index, block) in blocks.enumerated() {
            let blockString = nsAttributedBlock(block)
            result.append(blockString)
            if index < blocks.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }

        return result
    }

    // MARK: - Block → NSAttributedString

    private static func nsAttributedBlock(_ block: MarkdownBlock) -> NSAttributedString {
        switch block {

        case .heading(let level, let text):
            let font: UIFont
            switch level {
            case 1: font = UIFont.systemFont(ofSize: 22, weight: .bold)
            case 2: font = UIFont.systemFont(ofSize: 20, weight: .bold)
            case 3: font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            default: font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.label
            ]
            return NSAttributedString(string: inlineStripped(text), attributes: attrs)

        case .paragraph(let lines):
            let bodyFont = UIFont.preferredFont(forTextStyle: .body)
            return inlineNSAttributed(lines.joined(separator: " "), font: bodyFont)

        case .bulletItem(let text, let depth):
            let indent = String(repeating: "    ", count: depth)
            let bullet = depth == 0 ? "•" : "◦"
            let bodyFont = UIFont.preferredFont(forTextStyle: .body)

            let result = NSMutableAttributedString()
            let prefixAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.secondaryLabel
            ]
            result.append(NSAttributedString(string: "\(indent)\(bullet)  ", attributes: prefixAttrs))
            result.append(inlineNSAttributed(text, font: bodyFont))
            return result

        case .numberedItem(let number, let text):
            let bodyFont = UIFont.preferredFont(forTextStyle: .body)
            let result = NSMutableAttributedString()
            let prefixAttrs: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.label
            ]
            result.append(NSAttributedString(string: "\(number).  ", attributes: prefixAttrs))
            result.append(inlineNSAttributed(text, font: bodyFont))
            return result
        }
    }

    // MARK: - Inline Markdown → NSAttributedString
    //
    // Parses **bold**, *italic*, `code` inline within a run.
    // Falls back to plain text if markdown parsing fails.

    private static func inlineNSAttributed(_ raw: String, font: UIFont) -> NSAttributedString {
        guard !raw.isEmpty else {
            return NSAttributedString(string: "", attributes: [.font: font, .foregroundColor: UIColor.label])
        }

        // Try SwiftUI AttributedString markdown first, then convert
        if let swiftUIAttr = try? AttributedString(
            markdown: raw,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            // Convert AttributedString → NSAttributedString
            var nsAttr = try? NSAttributedString(swiftUIAttr, including: \.uiKit)
            if nsAttr == nil {
                nsAttr = NSAttributedString(swiftUIAttr)
            }

            if let nsAttr {
                // Apply base font & color where not already set by markdown
                let mutable = NSMutableAttributedString(attributedString: nsAttr)
                mutable.enumerateAttributes(in: NSRange(location: 0, length: mutable.length)) { attrs, range, _ in
                    if attrs[.font] == nil {
                        mutable.addAttribute(.font, value: font, range: range)
                    }
                    if attrs[.foregroundColor] == nil {
                        mutable.addAttribute(.foregroundColor, value: UIColor.label, range: range)
                    }
                }
                // Ensure bold/italic respect the base font size
                mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
                    guard let existingFont = value as? UIFont else { return }
                    let traits = existingFont.fontDescriptor.symbolicTraits
                    var newFont = font
                    if traits.contains(.traitBold) && traits.contains(.traitItalic) {
                        newFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) ?? font.fontDescriptor, size: 0)
                    } else if traits.contains(.traitBold) {
                        newFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitBold) ?? font.fontDescriptor, size: 0)
                    } else if traits.contains(.traitItalic) {
                        newFont = UIFont(descriptor: font.fontDescriptor.withSymbolicTraits(.traitItalic) ?? font.fontDescriptor, size: 0)
                    }
                    mutable.addAttribute(.font, value: newFont, range: range)
                }
                return mutable
            }
        }

        // Fallback: plain text
        return NSAttributedString(string: raw, attributes: [
            .font: font,
            .foregroundColor: UIColor.label
        ])
    }

    /// Strips markdown syntax characters for headings (they don't need inline parsing).
    private static func inlineStripped(_ raw: String) -> String {
        // Remove ** bold markers and * italic markers for heading display
        raw
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
    }

    // MARK: - Block Parser (unchanged)

    fileprivate static func parse(_ text: String) -> [MarkdownBlock] {
        let lines = text.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var paragraphLines: [String] = []

        func flushParagraph() {
            let joined = paragraphLines
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            if !joined.isEmpty {
                blocks.append(.paragraph(lines: joined))
            }
            paragraphLines = []
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty { flushParagraph(); continue }

            if trimmed.hasPrefix("#") {
                flushParagraph()
                let level = min(trimmed.prefix(while: { $0 == "#" }).count, 6)
                let headingText = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                if !headingText.isEmpty { blocks.append(.heading(level: level, text: headingText)) }
                continue
            }

            let leadingSpaces = line.prefix(while: { $0 == " " }).count
            let depth = leadingSpaces / 2

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                flushParagraph()
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                blocks.append(.bulletItem(text: itemText, depth: depth))
                continue
            }

            if let dotRange = trimmed.range(of: ". "),
               let number = Int(trimmed[trimmed.startIndex ..< dotRange.lowerBound]),
               number > 0 {
                flushParagraph()
                let itemText = String(trimmed[dotRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                blocks.append(.numberedItem(number: number, text: itemText))
                continue
            }

            paragraphLines.append(trimmed)
        }

        flushParagraph()
        return blocks
    }
}

// MARK: - Block Model

private enum MarkdownBlock: Identifiable {
    case heading(level: Int, text: String)
    case paragraph(lines: [String])
    case bulletItem(text: String, depth: Int)
    case numberedItem(number: Int, text: String)

    var id: String {
        switch self {
        case .heading(let l, let t):    return "h\(l)-\(t)"
        case .paragraph(let lines):     return "p-\(lines.joined())"
        case .bulletItem(let t, let d): return "b\(d)-\(t)"
        case .numberedItem(let n, let t): return "n\(n)-\(t)"
        }
    }
}

// MARK: - SelectableTextView (UIViewRepresentable)
//
// A self-sizing UITextView that:
//   • Is NOT editable   (user cannot type)
//   • IS selectable     (user gets blue highlight + drag handles + Copy popup)
//   • Sizes itself to fit its content (no fixed height)
//   • Has no scroll (outer SwiftUI ScrollView handles scrolling)
//   • Transparent background (bubble background comes from SwiftUI layer)

private struct SelectableTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    let isSelectable: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        // ── Interaction ───────────────────────────────────────────────
        textView.isEditable   = false      // no typing
        textView.isSelectable = true       // blue handles + Copy popup
        textView.dataDetectorTypes = []    // prevent links hijacking taps

        // ── Layout ────────────────────────────────────────────────────
        textView.isScrollEnabled          = false   // SwiftUI ScrollView handles scroll
        textView.backgroundColor          = .clear  // bubble bg from SwiftUI
        textView.textContainerInset       = .zero
        textView.textContainer.lineFragmentPadding = 0

        // ── Remove default intrinsic width constraint ─────────────────
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        // Only update if content actually changed to avoid selection reset
        if textView.attributedText != attributedText {
            textView.attributedText = attributedText
        }
        textView.isSelectable = isSelectable
    }

    // ── Self-sizing: tell SwiftUI how tall this view wants to be ──────
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        MarkdownTextView(content: """
        ### Key Features of Claude

        Claude is a powerful AI assistant developed by Anthropic.

        1. **Natural Language Processing (NLP):** Claude excels in understanding human language.
        2. **Contextual Understanding:** Claude understands context for more relevant responses.
        3. **Ethical AI Principles:** Alignment with ethical AI principles is a core feature.

        ### Applications of Claude

        - **Customer Support:** Handle customer inquiries automatically.
        - **Educational Tools:** Claude can serve as a virtual tutor.
        """)
        .padding()
    }
}

