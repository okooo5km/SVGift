// removeTitle.swift
// Plugin to remove <title> elements from SVG
// okooo5km(十里)

/// Remove `<title>` elements.
///
/// https://developer.mozilla.org/en-US/docs/Web/SVG/Element/title
///
/// - Example input:
///   `<title>My SVG</title>`
public func makeRemoveTitlePlugin() -> ResolvedPlugin {
    ResolvedPlugin(name: "removeTitle") { _, _, _ in
        return Visitor(
            element: VisitorCallbacks<XastElement>(
                enter: { node, parent in
                    if node.name == "title" {
                        detachNodeFromParent(.element(node), from: parent)
                    }
                    return .continue
                }
            )
        )
    }
}
