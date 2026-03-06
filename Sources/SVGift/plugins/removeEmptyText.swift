// removeEmptyText.swift
// Plugin to remove empty text elements
// okooo5km(十里)

import Foundation

/// Remove empty `<text>`, `<tspan>`, and `<tref>` elements.
///
/// Parameters:
/// - `text`: Remove empty `<text>` elements. Default: `"true"`.
/// - `tspan`: Remove empty `<tspan>` elements. Default: `"true"`.
/// - `tref`: Remove `<tref>` elements without `xlink:href`. Default: `"true"`.
public func makeRemoveEmptyTextPlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeEmptyText") { _, params, _ in
        let removeText = params["text"] != "false"
        let removeTspan = params["tspan"] != "false"
        let removeTref = params["tref"] != "false"

        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    if removeText && node.name == "text" && node.children.isEmpty {
                        detachNodeFromParent(.element(node), from: parent)
                        return .continue
                    }

                    if removeTspan && node.name == "tspan" && node.children.isEmpty {
                        detachNodeFromParent(.element(node), from: parent)
                        return .continue
                    }

                    if removeTref && node.name == "tref" {
                        if node.attributes["xlink:href"] == nil {
                            detachNodeFromParent(.element(node), from: parent)
                        }
                    }

                    return .continue
                }
            )
        )
    }
}
