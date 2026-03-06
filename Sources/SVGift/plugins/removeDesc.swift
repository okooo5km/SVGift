// removeDesc.swift
// Plugin to remove <desc> elements from SVG
// okooo5km(十里)

import Foundation

/// Standard editor-generated description patterns.
private let standardDescs = try! NSRegularExpression(pattern: "^(Created with|Created using)")

/// Remove `<desc>` elements.
///
/// By default, removes only empty `<desc>` elements or those containing
/// standard editor-generated content (e.g. "Created with Inkscape").
/// Set `removeAny` to `"true"` to remove all `<desc>` elements.
///
/// Parameters:
/// - `removeAny`: `"true"` to remove all desc elements. Default: `"false"`.
///
/// https://developer.mozilla.org/en-US/docs/Web/SVG/Element/desc
public func makeRemoveDescPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeDesc") { _, params, _ in
        let removeAny = params["removeAny"] == "true"

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    if node.name == "desc" {
                        if removeAny || node.children.isEmpty {
                            detachNodeFromParent(.element(node), from: parent)
                        } else if case .text(let textNode) = node.children.first {
                            let value = textNode.value
                            let range = NSRange(value.startIndex..<value.endIndex, in: value)
                            if standardDescs.firstMatch(in: value, range: range) != nil {
                                detachNodeFromParent(.element(node), from: parent)
                            }
                        }
                    }
                    return .continue
                }
            )
        )
    }
}
