// removeComments.swift
// Plugin to remove comments from SVG
// okooo5km(十里)

import Foundation

/// Remove comment nodes from the SVG AST.
///
/// By default, comments starting with `!` are preserved (e.g. `<!--! license -->`).
///
/// Parameters:
/// - `preservePatterns`: Comma-separated regex patterns. Comments matching any
///   pattern are preserved. Set to `"false"` to remove ALL comments.
///   Default: preserves comments starting with `!`.
///
/// - Example input:
///   `<!-- Generator: Adobe Illustrator 15.0.0 -->`
public func makeRemoveCommentsPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeComments") { _, params, _ in
        // Parse the preservePatterns parameter
        let preservePatterns: [NSRegularExpression]?

        if let preserveParam = params["preservePatterns"] {
            if preserveParam == "false" {
                // Explicitly disable all preservation
                preservePatterns = nil
            } else {
                // Parse comma-separated regex patterns
                let patterns = preserveParam.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                preservePatterns = patterns.compactMap { pattern in
                    try? NSRegularExpression(pattern: pattern)
                }
            }
        } else {
            // Default: preserve comments starting with !
            preservePatterns = [try! NSRegularExpression(pattern: "^!")]
        }

        return Visitor(
            comment: VisitorCallbacks<XastComment>(
                enter: { node, parent in
                    if let patterns = preservePatterns {
                        let value = node.value
                        let range = NSRange(value.startIndex..<value.endIndex, in: value)
                        let matches = patterns.contains { regex in
                            regex.firstMatch(in: value, range: range) != nil
                        }
                        if matches {
                            return .continue
                        }
                    }

                    detachNodeFromParent(.comment(node), from: parent)
                    return .continue
                }
            )
        )
    }
}
