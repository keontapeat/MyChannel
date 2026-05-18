#if canImport(Down)
import Down
#endif
import SwiftUI

/// Renders Markdown content in video descriptions, channel bios, and community posts.
struct MarkdownService {

    static func renderToAttributedString(_ markdown: String) -> AttributedString {
        #if canImport(Down)
        if let down = try? Down(markdownString: markdown),
           let nsAttr = try? down.toAttributedString() {
            if let result = try? AttributedString(nsAttr, including: \.uiKit) {
                return result
            }
        }
        #endif
        return (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }

    static func renderToHTML(_ markdown: String) -> String {
        #if canImport(Down)
        if let down = try? Down(markdownString: markdown),
           let html = try? down.toHTML() {
            return html
        }
        #endif
        return markdown
    }

    static func renderToPlainText(_ markdown: String) -> String {
        #if canImport(Down)
        if let down = try? Down(markdownString: markdown),
           let html = try? down.toHTML() {
            return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        }
        #endif
        return markdown
    }
}

/// SwiftUI view for rendering Markdown text.
struct MarkdownTextView: View {
    let markdown: String
    var font: Font = .body
    var foregroundColor: Color = .primary

    var body: some View {
        Text(MarkdownService.renderToAttributedString(markdown))
            .font(font)
            .foregroundColor(foregroundColor)
    }
}
