import AppShellCore
import SwiftUI

/// GitHub release notes (Markdown) → simple blocks. Headings, bullets and paragraphs are enough
/// for the notes the release scripts write; inline Markdown (bold, links, code) is kept per line.
public enum ReleaseNotes {
    public enum Block: Equatable, Sendable {
        case heading(String)
        case bullet(String)
        case paragraph(String)
    }

    public static func blocks(from markdown: String) -> [Block] {
        markdown.components(separatedBy: .newlines).compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { return nil }
            if line.hasPrefix("#") {
                return .heading(line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces))
            }
            for marker in ["- ", "* ", "+ "] where line.hasPrefix(marker) {
                return .bullet(String(line.dropFirst(marker.count)))
            }
            return .paragraph(line)
        }
    }
}

/// Renders release notes with system fonts.
public struct ReleaseNotesView: View {
    let blocks: [ReleaseNotes.Block]

    public init(markdown: String) { blocks = ReleaseNotes.blocks(from: markdown) }

    public var body: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.s) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let text):
                    Text(inline(text)).font(.headline).padding(.top, ShellTokens.Spacing.xs)
                case .bullet(let text):
                    HStack(alignment: .firstTextBaseline, spacing: ShellTokens.Spacing.s) {
                        Text(verbatim: "•").foregroundStyle(.secondary)
                        Text(inline(text))
                    }
                case .paragraph(let text):
                    Text(inline(text))
                }
            }
        }
        .font(.body)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}
